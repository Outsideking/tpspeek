from fastapi import FastAPI, Depends
from .models import Base, engine, SessionLocal, APIKey
from .auth import verify_api_key
import secrets

Base.metadata.create_all(bind=engine)

app = FastAPI(title="TPspeek API Key System")

# Endpoint สร้าง API Key
@app.post("/generate-key")
def generate_key():
    key = secrets.token_urlsafe(32)
    db = SessionLocal()
    db.add(APIKey(key=key))
    db.commit()
    db.close()
    return {"api_key": key}

# Endpoint ลิสต์ API Key (สำหรับ admin)
@app.get("/list-keys", dependencies=[Depends(verify_api_key)])
def list_keys():
    db = SessionLocal()
    keys = db.query(APIKey).all()
    db.close()
    return {"api_keys": [k.key for k in keys]}

# ตัวอย่าง endpoint ใช้งานจริง
@app.get("/protected-endpoint", dependencies=[Depends(verify_api_key)])
def protected():
    return {"message": "You have access to TPspeek API!"}
