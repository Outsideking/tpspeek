import os
import json
import time
import uuid
import boto3
from urllib.parse import urlparse

REGION = os.getenv("AWS_REGION", "ap-southeast-2")
S3_OUTPUT_BUCKET = os.getenv("OUTPUT_BUCKET")  # set by deploy script
TRANSCRIBE_ROLE_ARN = os.getenv("TRANSCRIBE_ROLE_ARN", "")  # optional if using service role

s3 = boto3.client("s3", region_name=REGION)
transcribe = boto3.client("transcribe", region_name=REGION)
translate = boto3.client("translate", region_name=REGION)
polly = boto3.client("polly", region_name=REGION)

def respond(status, body):
    return {"statusCode": status, "body": json.dumps(body), "headers": {"Content-Type": "application/json"}}

def start_transcribe_job(s3_uri, job_name, language_code="auto"):
    # Transcribe async - if language_code == 'auto', Amazon Transcribe auto language detection via StartTranscriptionJob supports 'IdentifyLanguage' features in some regions; here we call without set language for auto detection where supported.
    settings = {}
    if language_code and language_code != "auto":
        settings = {"LanguageCode": language_code}
    args = {
        "TranscriptionJobName": job_name,
        "Media": {"MediaFileUri": s3_uri},
        "OutputBucketName": S3_OUTPUT_BUCKET,
    }
    if language_code and language_code != "auto":
        args["LanguageCode"] = language_code
    # Start job
    transcribe.start_transcription_job(**args)
    return

def wait_for_transcript(job_name, timeout=300):
    start = time.time()
    while True:
        resp = transcribe.get_transcription_job(TranscriptionJobName=job_name)
        status = resp["TranscriptionJob"]["TranscriptionJobStatus"]
        if status == "COMPLETED":
            # get transcript URI and fetch
            uri = resp["TranscriptionJob"]["Transcript"]["TranscriptFileUri"]
            return uri
        if status in ("FAILED",):
            raise Exception("Transcription job failed")
        if time.time() - start > timeout:
            raise Exception("Transcription timeout")
        time.sleep(3)

def fetch_transcript_text(transcript_uri):
    # transcript_uri is an S3 signed url or s3:// ... handle http(s)
    import requests
    r = requests.get(transcript_uri)
    j = r.json()
    return j.get("results", {}).get("transcripts", [{}])[0].get("transcript", "")

def synthesize_text_to_s3(text, voice="Joanna", output_key=None, format="mp3"):
    if not output_key:
        output_key = f"tts/{uuid.uuid4().hex}.{format}"
    resp = polly.synthesize_speech(OutputFormat=format, Text=text, VoiceId=voice)
    audio_stream = resp.get("AudioStream")
    if audio_stream:
        s3.put_object(Bucket=S3_OUTPUT_BUCKET, Key=output_key, Body=audio_stream.read(), ServerSideEncryption="aws:kms")
        return f"s3://{S3_OUTPUT_BUCKET}/{output_key}"
    raise Exception("Polly failed to synthesize")

def handler(event, context):
    """
    Expected event (HTTP API proxy):
    - POST JSON {"text": "...", "target_lang":"en"}  => translate text and return tts S3 URI
    - POST JSON {"s3_uri": "s3://bucket/key", "target_lang":"en"} => transcribe -> translate -> tts -> return S3 URI
    """
    try:
        body = {}
        if event.get("body"):
            try:
                body = json.loads(event["body"])
            except:
                # if base64 or form decode if necessary
                body = {}
        # priority: s3_uri
        s3_uri = body.get("s3_uri")
        target_lang = body.get("target_lang", "en")
        voice = body.get("voice", None)  # optional (Polly voice id)
        if s3_uri:
            job_name = f"tpspeek-{uuid.uuid4().hex}"
            # support s3://bucket/key or https urls
            if s3_uri.startswith("s3://"):
                start_transcribe_job(s3_uri, job_name, language_code="auto")
            else:
                # if http(s) pointing to S3 signed url, Transcribe can access via URL; pass it directly
                start_transcribe_job(s3_uri, job_name, language_code="auto")
            transcript_uri = wait_for_transcript(job_name)
            text = fetch_transcript_text(transcript_uri)
        else:
            text = body.get("text", "")
            if not text:
                return respond(400, {"error": "No text or s3_uri provided"})
        # detect language via Translate API (DetectDominantLanguage not in Translate; use Comprehend for detection)
        # We'll call Translate->translate_text with SourceLanguageCode='auto' by using Comprehend to detect
        # Use Comprehend
        try:
            comprehend = boto3.client("comprehend", region_name=REGION)
            det = comprehend.detect_dominant_language(Text=text)
            source_lang = det["Languages"][0]["LanguageCode"] if det.get("Languages") else "auto"
        except Exception:
            source_lang = "auto"
        # Translate
        if source_lang == target_lang:
            translated_text = text
        else:
            tr = translate.translate_text(Text=text, SourceLanguageCode=source_lang if source_lang!="auto" else "auto", TargetLanguageCode=target_lang)
            translated_text = tr.get("TranslatedText", text)
        # Synthesize via Polly
        polly_voice = voice or ("Joanna" if target_lang.startswith("en") else "Aditi" if target_lang.startswith("hi") else "Matthew" if target_lang.startswith("en") else "Joanna")
        tts_s3_uri = synthesize_text_to_s3(translated_text, voice=polly_voice)
        return respond(200, {"original": text, "translated": translated_text, "tts_s3_uri": tts_s3_uri, "source_lang": source_lang})
    except Exception as e:
        return respond(500, {"error": str(e)})
