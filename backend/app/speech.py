import os
USE_EXTERNAL = os.getenv('USE_EXTERNAL_STT_TTS', 'true').lower() == 'true'

# Placeholder functions. For production, either call cloud STT/TTS services or load local models.

def speech_to_text_local(audio_path: str, lang: str) -> str:
    try:
        import whisper
        model = whisper.load_model('base')
        res = model.transcribe(audio_path, language=lang)
        return res.get('text','')
    except Exception as e:
        return f"_error_load_whisper_: {e}"

def text_to_speech_local(text: str, lang: str) -> str:
    # Placeholder: write text to WAV using pyttsx3 or call external TTS. We return a path to generated file.
    from gtts import gTTS
    out = f"/data/tts_{lang}.mp3"
    tts = gTTS(text=text, lang=lang if lang!='auto' else 'en')
    tts.save(out)
    return out

# Public wrappers
def speech_to_text(audio_path: str, lang: str) -> str:
    if USE_EXTERNAL:
        # call external API e.g., OpenAI Whisper API (if desired)
        # Fallback to local
        return speech_to_text_local(audio_path, lang)
    else:
        return speech_to_text_local(audio_path, lang)

def text_to_speech(text: str, lang: str) -> str:
    if USE_EXTERNAL:
        return text_to_speech_local(text, lang)
    else:
        return text_to_speech_local(text, lang)
