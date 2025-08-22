from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta

router = APIRouter(prefix="/auth", tags=["auth"])
SECRET_KEY = "tpspeek-secret-key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

_users_db = {
    "admin": {"username": "admin", "hashed_password": pwd_context.hash("admin123"), "role": "superadmin"}
}

class User(BaseModel):
    username: str
    role: str

class UserIn(BaseModel):
    username: str
    password: str
    role: Optional[str] = "user"

class LoginIn(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_user(username: str):
    return _users_db.get(username)

def authenticate_user(username: str, password: str):
    user = get_user(username)
    if not user or not verify_password(password, user["hashed_password"]):
        return False
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta if expires_delta else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

@router.post("/login", response_model=Token)
def login(login_in: LoginIn):
    user = authenticate_user(login_in.username, login_in.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    token = create_access_token({"sub": user["username"], "role": user["role"]})
    return {"access_token": token, "token_type": "bearer"}

@router.post("/add_user", response_model=User)
def add_user(user_in: UserIn):
    if user_in.username in _users_db:
        raise HTTPException(status_code=400, detail="User already exists")
    hashed_password = pwd_context.hash(user_in.password)
    _users_db[user_in.username] = {"username": user_in.username, "hashed_password": hashed_password, "role": user_in.role}
    return {"username": user_in.username, "role": user_in.role}

@router.get("/users", response_model=List[User])
def list_users():
    return [{"username": u["username"], "role": u["role"]} for u in _users_db.values()]

@router.delete("/delete_user/{username}")
def delete_user(username: str):
    if username not in _users_db:
        raise HTTPException(status_code=404, detail="User not found")
    del _users_db[username]
    return {"detail": f"User {username} deleted"}

@router.put("/update_user/{username}", response_model=User)
def update_user(username: str, user_in: UserIn):
    if username not in _users_db:
        raise HTTPException(status_code=404, detail="User not found")
    hashed_password = pwd_context.hash(user_in.password)
    _users_db[username] = {"username": user_in.username, "hashed_password": hashed_password, "role": user_in.role}
    return {"username": user_in.username, "role": user_in.role}
