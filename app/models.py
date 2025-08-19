from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime, timedelta

DATABASE_URL = "sqlite:///./tpspeek_users.db"

Base = declarative_base()
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    api_key = Column(String, unique=True)
    version = Column(Integer, default=1)
    num_languages = Column(Integer, default=1)
    monthly_price = Column(Float, default=100.0)
    yearly_price = Column(Float, default=0.0)
    plan_start = Column(DateTime, default=datetime.utcnow)
    plan_end = Column(DateTime, default=datetime.utcnow() + timedelta(days=30))
    active = Column(Boolean, default=True)
    is_scanzaclip = Column(Boolean, default=False)
