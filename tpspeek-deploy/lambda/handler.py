import boto3
import json
import base64

translate = boto3.client('translate')
polly = boto3.client('polly')

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    text = body.get('text', '')
    source_lang = body.get('source', 'auto')
    target_lang = body.get('target', 'en')

    # แปลภาษา
    result = translate.translate_text(
        Text=text,
        SourceLanguageCode=source_lang,
        TargetLanguageCode=target_lang
    )
    translated_text = result['TranslatedText']

    # สร้างเสียง
    speech = polly.synthesize_speech(
        Text=translated_text,
        VoiceId="Joanna",
        OutputFormat="mp3"
    )
    audio_stream = speech['AudioStream'].read()
    audio_base64 = base64.b64encode(audio_stream).decode('utf-8')

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "translated_text": translated_text,
            "audio_base64": audio_base64
        })
  }
