from fastapi import APIRouter
from .users import list_users

router = APIRouter()

@router.get('/admin/users')
def get_users():
    users = list_users()
    return users
