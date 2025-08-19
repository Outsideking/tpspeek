from fastapi import Request, HTTPException
from .users import get_user_by_key

async def verify_api_key(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or "Bearer " not in auth_header:
        raise HTTPException(status_code=401, detail="Missing API Key")
    token = auth_header.split(" ")[1]
    user = get_user_by_key(token)
    if not user:
        raise HTTPException(status_code=403, detail="Invalid API Key")
    return user
