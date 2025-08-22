from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import uuid, time

router = APIRouter(prefix="/api-keys", tags=["api-manager"])

class KeyIn(BaseModel):
    module: str
    permissions: list[str]

_store = {}

@router.post("/")
def create_key(body: KeyIn):
    kid = uuid.uuid4().hex
    _store[kid] = {"module": body.module, "permissions": body.permissions, "created": time.time()}
    return {"key": kid, "module": body.module}

@router.get("/{key}")
def get_key(key: str):
    if key in _store:
        return _store[key]
    raise HTTPException(status_code=404, detail="Key not found")
