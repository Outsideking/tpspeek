from fastapi import FastAPI
from app.backend.login import routes as login_routes

app = FastAPI(title="TPspeek Backend")

# รวม router
app.include_router(login_routes.router, prefix="/auth", tags=["Auth"])

@app.get("/")
def root():
    return {"message": "Welcome to TPspeek Backend 🚀"}
