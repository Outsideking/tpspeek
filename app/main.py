# FastAPI main app
from fastapi import FastAPI, UploadFile, File, Form, Depends
from .models import Base, engine, SessionLocal, APIKey
from .auth import verify_api_key
from .translation import translate_text
from .speech import speech_to_text, text_to_speech
from fastapi.responses import JSONResponse

Base.metadata.create_all(bind=engine)
app = FastAPI(title="TPspeek API")

# Generate API Key Endpoint
@app.post("/generate-key")
def generate_key():
    import secrets
    key = secrets.token_urlsafe(32)
    db = SessionLocal()
    db.add(APIKey(key=key))
    db.commit()
    db.close()
    return {"api_key": key}

# Translation Endpoint
@app.post("/translate")
def translate(text: str = Form(...), source_lang: str = Form(...), target_lang: str = Form(...), request=Depends(verify_api_key)):
    translated = translate_text(text, source_lang, target_lang)
    return {"translated_text": translated}

# Speech-to-Text Endpoint
@app.post("/speech-to-text")
def stt(file: UploadFile = File(...), lang: str = Form(...), request=Depends(verify_api_key)):
    tmp_path = f"/tmp/{file.filename}"
    with open(tmp_path, "wb") as f:
        f.write(file.file.read())
    text = speech_to_text(tmp_path, lang)
    return {"text": text}

# Text-to-Speech Endpoint
@app.post("/text-to-speech")
def tts(text: str = Form(...), lang: str = Form(...), request=Depends(verify_api_key)):
    audio_url = text_to_speech(text, lang)
    return {"audio_url": audio_url}
