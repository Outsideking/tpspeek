from fastapi import FastAPI
from app import auth, api_manager, finance, automation, translation

app = FastAPI(title="TPspeek_Enterprise Backend")

app.include_router(auth.router)
app.include_router(api_manager.router)
app.include_router(finance.router)
app.include_router(automation.router)
app.include_router(translation.router)

@app.get("/health")
def health():
    return {"status":"ok"}
