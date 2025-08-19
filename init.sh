#!/bin/bash
set -e
PROJECT_DIR=$(pwd)
mkdir -p backend/app frontend data
cat > .env.example <<'ENV'
OPENAI_API_KEY=
USE_EXTERNAL_STT_TTS=true
ADMIN_EMAIL=admin@example.com
ENV
# (the rest of files are included in this repo doc; please save them into the right paths)
echo "Scaffold created. Edit .env and run: docker-compose up -d --build"
