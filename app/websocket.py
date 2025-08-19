from fastapi import WebSocket
from .translation import translate_text

class RealtimeTranslator:
    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        while True:
            data = await websocket.receive_json()
            text = data.get("text")
            source = data.get("source_lang")
            target = data.get("target_lang")
            translated = translate_text(text, source, target)
            await websocket.send_json({"translated_text": translated})
