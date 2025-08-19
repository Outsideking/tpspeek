from fastapi import FastAPI, UploadFile, File, Form, Depends, WebSocket
from .models import Base, engine, SessionLocal, User
from .auth import verify_api_key
from .translation import translate_text
from .speech import speech_to_text, text_to_speech
from .websocket import RealtimeTranslator
from .users import create_user

Base.metadata.create_all(bind=engine)
app = FastAPI(title="TPspeek Full-stack API")
realtime_translator = RealtimeTranslator()

@app.post("/generate-key")
def generate_key(name: str = Form(...), email: str = Form(...), version: int = Form(1), num_languages: int = Form(1), is_scanzaclip: bool = Form(False)):
    user = create_user(name, email, version, num_languages, is_scanzaclip)
    return {"api_key": user.api_key, "version": user.version, "monthly_price": user.monthly_price, "yearly_price": user.yearly_price, "plan_end": user.plan_end}

@app.post("/translate")
def translate(text: str = Form(...), source_lang: str = Form(...), target_lang: str = Form(...), request=Depends(verify_api_key)):
    translated = translate_text(text, source_lang, target_lang)
    return {"translated_text": translated}

@app.post("/speech-to-text")
def stt(file: UploadFile = File(...), lang: str = Form(...), request=Depends(verify_api_key)):
    tmp_path = f"/tmp/{file.filename}"
    with open(tmp_path, "wb") as f: f.write(file.file.read())
    text = speech_to_text(tmp_path, lang)
    return {"text": text}

@app.post("/text-to-speech")
def tts(text: str = Form(...), lang: str = Form(...), request=Depends(verify_api_key)):
    audio_path = text_to_speech(text, lang)
    return {"audio_path": audio_path}

@app.websocket("/ws/translate")
async def websocket_translate(ws: WebSocket):
    await realtime_translator.connect(ws)
