from fastapi import FastAPI

app = FastAPI(title="Your Project API")

@app.get("/healthz")
def healthz():
    return {"status": "ok"}

@app.get("/add")
def add(a: int, b: int):
    return {"sum": a + b}
