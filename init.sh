#!/bin/bash
echo "🚀 TPspeek Auto Setup Start..."

# อัปเดตเซิร์ฟเวอร์
apt-get update && apt-get upgrade -y
apt-get install -y docker.io docker-compose git

# ดึงโค้ดจาก repo (กรณีคุณใส่ GitHub/Gitee)
# git clone https://github.com/yourrepo/tpspeek.git
cd tpspeek

# สร้าง ENV
echo "OPENAI_API_KEY=ใส่คีย์ของคุณ" > .env

# สร้าง container
docker-compose up -d --build

echo "✅ ติดตั้งเสร็จแล้ว! เปิดใช้งานได้ที่ http://YOUR_SERVER_IP/"
