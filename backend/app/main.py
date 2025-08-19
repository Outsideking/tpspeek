from fastapi import FastAPI, UploadFile, File, Form, Depends, WebSocket
from .models import init_db
from .auth import verify_api_key
from .translation import translate_text
from .speech import speech_to_text, text_to_speech
from .websocket import RealtimeTranslator
from .users import create_user
from .admin import router as admin_router

init_db()
app = FastAPI(title='TPspeek Fullstack')
realtime = RealtimeTranslator()

app.include_router(admin_router)

@app.post('/generate-key')
def generate_key(name: str = Form(...), email: str = Form(...), version: int = Form(1), num_languages: int = Form(1), is_scanzaclip: bool = Form(False)):
    user = create_user(name, email, version, num_languages, is_scanzaclip)
    return {'api_key': user.api_key, 'version': user.version, 'monthly_price': user.monthly_price, 'yearly_price': user.yearly_price, 'plan_end': user.plan_end}

@app.post('/translate')
def translate(text: str = Form(...), source_lang: str = Form(...), target_lang: str = Form(...), user = Depends(verify_api_key)):
    translated = translate_text(text, source_lang, target_lang)
    return {'translated_text': translated}

@app.post('/speech-to-text')
def stt(file: UploadFile = File(...), lang: str = Form('en'), user = Depends(verify_api_key)):
    tmp = f'/data/{file.filename}'
    with open(tmp, 'wb') as f:
        f.write(file.file.read())
    text = speech_to_text(tmp, lang)
    return {'text': text}

@app.post('/text-to-speech')
def tts(text: str = Form(...), lang: str = Form('en'), user = Depends(verify_api_key)):
    path = text_to_speech(text, lang)
    return {'audio_path': path}

@app.websocket('/ws/translate')
async def ws_translate(ws: WebSocket):
    await realtime.connect(ws)
