from fastapi import APIRouter, File, UploadFile
from pydantic import BaseModel
from ai.tts_stt import text_to_speech, speech_to_text, translate_text

router = APIRouter(prefix="/translate", tags=["translate"])

class TextIn(BaseModel):
    text: str
    source_lang: str
    target_lang: str

@router.post("/text")
def translate_text_endpoint(body: TextIn):
    translated = translate_text(body.text, body.source_lang, body.target_lang)
    return {"translated_text": translated}

@router.post("/speech")
async def translate_speech(file: UploadFile, target_lang: str):
    speech_text = await speech_to_text(file)
    translated = translate_text(speech_text, "auto", target_lang)
    audio_file = text_to_speech(translated, target_lang)
    return {"translated_text": translated, "audio_file": audio_file}
