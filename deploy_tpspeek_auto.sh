#!/bin/bash
# TPspeek Full Auto Deployment Script with Auto-update & SSL Renewal
# Usage: bash deploy_tpspeek_auto.sh your_domain.com your_openai_api_key

DOMAIN=$1
OPENAI_KEY=$2

if [ -z "$DOMAIN" ] || [ -z "$OPENAI_KEY" ]; then
  echo "Usage: bash deploy_tpspeek_auto.sh your_domain.com your_openai_api_key"
  exit 1
fi

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing required packages..."
sudo apt install -y python3-pip docker.io docker-compose certbot cron

echo "Creating project directory..."
mkdir -p ~/tpspeek
cd ~/tpspeek

echo "Creating requirements.txt..."
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

echo "Creating Dockerfile..."
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

echo "Creating docker-compose.yml..."
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

echo "Creating directories..."
mkdir -p app web_ui certs

# Web UI index.html
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

echo "Obtaining SSL certificate..."
sudo certbot certonly --standalone -d $DOMAIN --agree-tos -m admin@$DOMAIN --non-interactive

echo "Copying certificates..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./certs/
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./certs/

echo "Deploying Docker container..."
sudo docker-compose build
sudo docker-compose up -d

echo "Setting up auto-update Docker container..."
(crontab -l 2>/dev/null; echo "0 4 * * * cd ~/tpspeek && sudo docker-compose pull && sudo docker-compose up -d") | crontab -

echo "Setting up SSL auto-renewal..."
(crontab -l 2>/dev/null; echo "0 3 * * * sudo certbot renew --post-hook 'docker-compose restart tpspeek'") | crontab -

echo "TPspeek deployment complete!"
echo "Open https://$DOMAIN to generate API Key and start using the API."
echo "Auto-update and SSL renewal configured."
