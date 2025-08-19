
from fastapi import HTTPException
from .models import User, SessionLocal
import secrets
from .billing import calculate_price
from datetime import datetime, timedelta

def create_user(name:str, email:str, version:int=1, num_languages:int=1, is_scanzaclip:bool=False):
    db = SessionLocal()
    api_key = secrets.token_urlsafe(32)
    monthly, yearly = calculate_price(version, num_languages)
    plan_end = datetime.utcnow() + timedelta(days=30)
    user = User(name=name, email=email, api_key=api_key, version=version,
                num_languages=num_languages, monthly_price=monthly, yearly_price=yearly,
                plan_end=plan_end, active=True, is_scanzaclip=is_scanzaclip)
    db.add(user)
    db.commit()
    db.refresh(user)
    db.close()
    return user
