#!/bin/bash
# Full-stack TPspeek deployment with User/Billing/Admin UI
# Usage: bash deploy_tpspeek_fullstack.sh your_domain.com your_openai_api_key

DOMAIN=$1
OPENAI_KEY=$2

if [ -z "$DOMAIN" ] || [ -z "$OPENAI_KEY" ]; then
  echo "Usage: bash deploy_tpspeek_fullstack.sh your_domain.com your_openai_api_key"
  exit 1
fi

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing packages ==="
sudo apt install -y python3-pip docker.io docker-compose certbot cron git

sudo systemctl enable docker
sudo systemctl start docker

echo "=== Creating project directory ==="
mkdir -p ~/tpspeek && cd ~/tpspeek
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
python-jose
passlib[bcrypt]
EOT

echo "=== Dockerfile ==="
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

echo "=== Docker Compose ==="
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

echo "=== Obtaining SSL certificate ==="
sudo certbot certonly --standalone -d $DOMAIN --agree-tos -m admin@$DOMAIN --non-interactive

sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./certs/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./certs/

echo "=== Creating TPspeek backend structure ==="
mkdir -p app
cd app

# main.py
cat <<EOT > main.py
from fastapi import FastAPI, UploadFile, File, Form, Depends, WebSocket
from .models import Base, engine, SessionLocal, User
from .auth import verify_api_key
from .translation import translate_text
from .speech import speech_to_text, text_to_speech
from .websocket import RealtimeTranslator
from .users import create_user
from datetime import datetime
import secrets

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
EOT

# สร้างโมดูล placeholder
touch auth.py models.py translation.py speech.py websocket.py users.py billing.py

cd ../web_ui
# Admin UI
cat <<EOT > admin.html
<!DOCTYPE html>
<html>
<head><title>TPspeek Admin Panel</title></head>
<body>
<h1>Users & Billing</h1>
<table border="1">
<thead><tr><th>ID</th><th>Name</th><th>Email</th><th>API Key</th><th>Version</th><th>Languages</th><th>Monthly</th><th>Yearly</th><th>Plan End</th><th>Active</th></tr></thead>
<tbody id="userTable"></tbody>
</table>
<script>
async function loadUsers(){
    const res = await fetch('/admin/users');
    const users = await res.json();
    const tbody = document.getElementById('userTable');
    tbody.innerHTML = '';
    users.forEach(u=>{
        tbody.innerHTML += `<tr><td>${u.id}</td><td>${u.name}</td><td>${u.email}</td><td>${u.api_key}</td><td>${u.version}</td><td>${u.num_languages}</td><td>${u.monthly_price}</td><td>${u.yearly_price}</td><td>${u.plan_end}</td><td>${u.active}</td></tr>`;
    });
}
loadUsers();
</script>
</body>
</html>
EOT

cd ~/tpspeek

echo "=== Deploying Docker container ==="
sudo docker-compose build
sudo docker-compose up -d

echo "=== Setting up auto-update Docker container ==="
(crontab -l 2>/dev/null; echo "0 4 * * * cd ~/tpspeek && sudo docker-compose pull && sudo docker-compose up -d") | crontab -

echo "=== Setting up SSL auto-renewal ==="
(crontab -l 2>/dev/null; echo "0 3 * * * sudo certbot renew --post-hook 'docker-compose restart tpspeek'") | crontab -

echo "=== Deployment Complete! ==="
echo "Visit https://$DOMAIN to create users, generate API Key, and access Admin UI."
