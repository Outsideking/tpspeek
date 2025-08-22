from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime
router = APIRouter(prefix="/finance", tags=["finance"])

_accounts = {}
_invoices = {}

class Account(BaseModel):
    name: str
    balance: float

class Invoice(BaseModel):
    account: str
    amount: float
    tax_percent: float

@router.post("/account")
def create_account(a: Account):
    if a.name in _accounts:
        raise HTTPException(400, "Account exists")
    _accounts[a.name] = a
    return a

@router.post("/invoice")
def create_invoice(inv: Invoice):
    if inv.account not in _accounts:
        raise HTTPException(404, "Account not found")
    tax = inv.amount * inv.tax_percent / 100
    _accounts[inv.account].balance -= inv.amount + tax
    _invoices[datetime.utcnow().isoformat()] = inv.dict()
    return {"status": "paid", "tax": tax}
