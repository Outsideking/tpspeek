from fastapi import FastAPI
from backend import auth, api_manager, translation

app = FastAPI(title="TPspeek Backend Full")

app.include_router(auth.router)
app.include_router(api_manager.router)
app.include_router(translation.router)

@app.get("/health")
def health():
    return {"status": "ok"}
