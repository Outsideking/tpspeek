from fastapi import Request, HTTPException
from .models import SessionLocal, User

def verify_api_key(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or "Bearer " not in auth_header:
        raise HTTPException(status_code=401, detail="Missing API Key")
    token = auth_header.split(" ")[1]
    db = SessionLocal()
    key = db.query(User).filter(User.api_key == token, User.active==True).first()
    db.close()
    if not key:
        raise HTTPException(status_code=403, detail="Invalid API Key")
