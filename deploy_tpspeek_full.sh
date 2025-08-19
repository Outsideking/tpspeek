#!/bin/bash
# Full Auto Deployment TPspeek on Alibaba Cloud ECS
# Zero-to-Production with HTTPS, API Key, Auto-update, SSL Renewal
# Usage: bash deploy_tpspeek_full.sh your_domain.com your_openai_api_key

DOMAIN=$1
OPENAI_KEY=$2

if [ -z "$DOMAIN" ] || [ -z "$OPENAI_KEY" ]; then
  echo "Usage: bash deploy_tpspeek_full.sh your_domain.com your_openai_api_key"
  exit 1
fi

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing packages ==="
sudo apt install -y python3-pip docker.io docker-compose certbot cron git

echo "=== Enabling Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Creating project directory ==="
mkdir -p ~/tpspeek
cd ~/tpspeek

echo "=== Creating app directories ==="
mkdir -p app web_ui certs

echo "=== Creating requirements.txt ==="
cat <<EOT > requirements.txt
fastapi
uvicorn[standard]
pydantic
sqlalchemy
python-multipart
websockets
openai
coqui-ai-tts
whisper
EOT

echo "=== Creating Dockerfile ==="
cat <<EOT > Dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ ./app/
COPY web_ui/ ./web_ui/
ENV OPENAI_API_KEY=$OPENAI_KEY
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "443", "--ssl-keyfile", "/certs/privkey.pem", "--ssl-certfile", "/certs/fullchain.pem"]
EOT

echo "=== Creating docker-compose.yml ==="
cat <<EOT > docker-compose.yml
version: '3.8'
services:
  tpspeek:
    build: .
    container_name: tpspeek
    ports:
      - "443:443"
    environment:
      - OPENAI_API_KEY=$OPENAI_KEY
    volumes:
      - ./app:/app
      - ./web_ui:/web_ui
      - ./certs:/certs
EOT

echo "=== Creating basic Web UI ==="
cat <<EOT > web_ui/index.html
<!DOCTYPE html>
<html>
<head><title>TPspeek API Key Manager</title></head>
<body>
<h1>TPspeek API Key Generator</h1>
<form id="keyForm"><button type="submit">Generate API Key</button></form>
<pre id="result"></pre>
<script>
const form=document.getElementById('keyForm');const result=document.getElementById('result');
form.addEventListener('submit',async(e)=>{e.preventDefault();
fetch('/generate-key',{method:'POST'}).then(r=>r.json()).then(data=>{result.textContent=JSON.stringify(data,null,2);});
});
</script>
</body>
</html>
EOT

echo "=== Obtaining SSL certificate via certbot ==="
sudo certbot certonly --standalone -d $DOMAIN --agree-tos -m admin@$DOMAIN --non-interactive

echo "=== Copying SSL certificates ==="
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./certs/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./certs/

echo "=== Creating skeleton FastAPI app ==="
cat <<EOT > app/main.py
from fastapi import FastAPI, UploadFile, File, Form, Depends, WebSocket
from .auth import verify_api_key
from .models import Base, engine, SessionLocal, APIKey
import secrets
from .translation import translate_text
from .speech import speech_to_text, text_to_speech
from .websocket import RealtimeTranslator

Base.metadata.create_all(bind=engine)
app = FastAPI(title="TPspeek Full API")
realtime_translator = RealtimeTranslator()

@app.post("/generate-key")
def generate_key():
    key = secrets.token_urlsafe(32)
    db = SessionLocal()
    db.add(APIKey(key=key))
    db.commit()
    db.close()
    return {"api_key": key}

@app.post("/translate")
def translate(text: str = Form(...), source_lang: str = Form(...), target_lang: str = Form(...), request=Depends(verify_api_key)):
    translated = translate_text(text, source_lang, target_lang)
    return {"translated_text": translated}

@app.post("/speech-to-text")
def stt(file: UploadFile = File(...), lang: str = Form(...), request=Depends(verify_api_key)):
    tmp_path = f"/tmp/{file.filename}"
    with open(tmp_path, "wb") as f:
        f.write(file.file.read())
    text = speech_to_text(tmp_path, lang)
    return {"text": text}

@app.post("/text-to-speech")
def tts(text: str = Form(...), lang: str = Form(...), request=Depends(verify_api_key)):
    audio_path = text_to_speech(text, lang)
    return {"audio_path": audio_path}

@app.websocket("/ws/translate")
async def websocket_translate(ws: WebSocket):
    await realtime_translator.connect(ws)
EOT

echo "=== Creating placeholder modules ==="
touch app/auth.py app/models.py app/translation.py app/speech.py app/websocket.py

echo "=== Deploying Docker container ==="
sudo docker-compose build
sudo docker-compose up -d

echo "=== Setting up auto-update Docker container ==="
(crontab -l 2>/dev/null; echo "0 4 * * * cd ~/tpspeek && sudo docker-compose pull && sudo docker-compose up -d") | crontab -

echo "=== Setting up SSL auto-renewal ==="
(crontab -l 2>/dev/null; echo "0 3 * * * sudo certbot renew --post-hook 'docker-compose restart tpspeek'") | crontab -

echo "=== Deployment Complete! ==="
echo "Visit https://$DOMAIN to generate API Key and start using TPspeek API."
echo "Auto-update and SSL renewal are configured."
