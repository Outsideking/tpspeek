from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from app.backend.login import utils, service, schemas

router = APIRouter()

# mock user (ยังไม่เชื่อม DB จริง)
fake_user = {
    "username": "admin",
    "hashed_password": utils.hash_password("1234")
}

@router.post("/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    if form_data.username != fake_user["username"] or not utils.verify_password(
        form_data.password, fake_user["hashed_password"]
    ):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = service.create_access_token({"sub": form_data.username})
    return {"access_token": token, "token_type": "bearer"}
