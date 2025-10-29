from fastapi.testclient import TestClient
from src.your_project.app import app

client = TestClient(app)

def test_healthz():
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}

def test_add():
    res = client.get("/add", params={"a": 2, "b": 3})
    assert res.status_code == 200
    assert res.json()["sum"] == 5
