# STT & TTS logic
# ตัวอย่าง STT & TTS (dummy)
def speech_to_text(audio_file_path: str, lang: str) -> str:
    # TODO: integrate Whisper/STT model
    return f"[Recognized {lang}] dummy text"

def text_to_speech(text: str, lang: str) -> str:
    # TODO: integrate Coqui/OpenAI TTS
    audio_url = "https://example.com/dummy_audio.mp3"
    return audio_url
