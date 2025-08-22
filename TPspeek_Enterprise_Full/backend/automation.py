from fastapi import APIRouter
router = APIRouter(prefix="/automation", tags=["automation"])

_office_roles = {
    "manager": ["approve_budget","view_reports"],
    "staff": ["submit_report"]
}

@router.get("/permissions/{role}")
def get_permissions(role: str):
    return {"role": role, "permissions": _office_roles.get(role, [])}
