from fastapi import APIRouter
from .models import SessionLocal, User

router = APIRouter()

@router.get("/admin/users")
def get_users():
    db = SessionLocal()
    users = db.query(User).all()
    db.close()
    return users
