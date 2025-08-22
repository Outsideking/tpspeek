from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import hashlib

router = APIRouter(prefix="/auth", tags=["auth"])

_users = {
    "admin": {"password_hash": hashlib.sha256(b"admin").hexdigest(), "role": "superadmin"}
}

class LoginIn(BaseModel):
    username: str
    password: str

@router.post("/login")
def login(info: LoginIn):
    user = _users.get(info.username)
    if user and user["password_hash"] == hashlib.sha256(info.password.encode()).hexdigest():
        return {"access_token": "fake-token", "role": user["role"]}
    raise HTTPException(status_code=401, detail="Invalid credentials")
