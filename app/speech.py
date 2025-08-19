import whisper
from coqui_ai_tts import TTS

# โหลดโมเดล
stt_model = whisper.load_model("base")
tts_model = TTS("en-us")  # ปรับภาษาตามต้องการ

def speech_to_text(audio_file_path: str, lang: str) -> str:
    result = stt_model.transcribe(audio_file_path, language=lang)
    return result["text"]

def text_to_speech(text: str, lang: str) -> str:
    file_path = f"/tmp/output_{lang}.wav"
    tts_model.tts_to_file(text=text, file_path=file_path, speaker=lang)
    return file_path
