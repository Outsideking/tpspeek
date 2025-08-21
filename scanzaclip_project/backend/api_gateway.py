from fastapi import FastAPI, UploadFile, Form
from fastapi.responses import JSONResponse
import requests, shutil, os

app = FastAPI()
TPSPEEK_URL = "http://tpspeek_backend:8000"
API_KEY = os.getenv("TPSPEEK_API_KEY", "YOUR_API_KEY")

@app.post("/auto_translate_audio/")
async def auto_translate_audio(file: UploadFile, target_lang: str = Form(...)):
    temp_path = f"/tmp/{file.filename}"
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    resp = requests.post(
        f"{TPSPEEK_URL}/stt_translate",
        headers={"Authorization": f"Bearer {API_KEY}"},
        json={"file_uri": temp_path, "target_lang": target_lang}
    )
    return JSONResponse(content=resp.json())

@app.post("/auto_translate_text/")
async def auto_translate_text(text: str = Form(...), target_lang: str = Form(...)):
    resp = requests.post(
        f"{TPSPEEK_URL}/translate",
        headers={"Authorization": f"Bearer {API_KEY}"},
        json={"text": text, "source_lang": "auto", "target_lang": target_lang}
    )
    return JSONResponse(content=resp.json())
