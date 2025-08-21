#!/bin/bash
# run.sh - Build & Run Scanzaclip + TPspeek

echo "✅ Building and starting all services..."
docker-compose up --build
chmod +x run.sh
./run.sh
