#!/bin/bash
# Push script for TPspeek

# ตั้งค่า
REPO_URL="https://github.com/Outsideking/tpspeek.git"
BRANCH="main"

# ตรวจสอบว่ามี git หรือยัง
if ! command -v git &> /dev/null
then
    echo "❌ ไม่พบ git โปรดติดตั้งก่อน"
    exit 1
fi

# ตรวจสอบว่าเป็น git repo ไหม
if [ ! -d ".git" ]; then
    echo "⚡ Initializing new git repository..."
    git init
    git remote add origin $REPO_URL
fi

# ดึง remote ก่อนป้องกัน conflict
git fetch origin $BRANCH

# เพิ่มไฟล์ทั้งหมด
git add .

# commit พร้อมใส่เวลาปัจจุบัน
git commit -m "Auto push: $(date '+%Y-%m-%d %H:%M:%S')"

# ตั้ง branch เป็น main
git branch -M $BRANCH

# push ไป origin
git push -u origin $BRANCH

echo "✅ Push เสร็จแล้ว ไปดูที่ GitHub: $REPO_URL"
