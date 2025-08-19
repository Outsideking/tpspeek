# API Key authentication
from fastapi import Request, HTTPException
from .models import SessionLocal, APIKey

def verify_api_key(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or "Bearer " not in auth_header:
        raise HTTPException(status_code=401, detail="Missing API Key")
    token = auth_header.split(" ")[1]
    db = SessionLocal()
    key = db.query(APIKey).filter(APIKey.key == token).first()
    db.close()
    if not key:
        raise HTTPException(status_code=403, detail="Invalid API Key")
