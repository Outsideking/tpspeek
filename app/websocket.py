# Realtime translation
from fastapi import WebSocket

class RealtimeTranslator:
    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        while True:
            data = await websocket.receive_text()
            # TODO: แปลข้อความทันที
            await websocket.send_text(f"[Realtime Translation]: {data}")
