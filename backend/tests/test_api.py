import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data

def test_webhook_session_completed_accepts_background_task():
    payload = {
        "type": "UPDATE",
        "table": "training_session",
        "record": {
            "session_id": 9999,
            "session_status": "completed",
            "user_id": 1
        }
    }
    response = client.post("/webhook/session-completed", json=payload)
    assert response.status_code == 202
    data = response.json()
    assert data["status"] == "accepted"
    assert data["session_id"] == 9999

def test_webhook_ignores_non_completed_status():
    payload = {
        "record": {
            "session_id": 9999,
            "session_status": "running"
        }
    }
    response = client.post("/webhook/session-completed", json=payload)
    assert response.status_code == 202
    data = response.json()
    assert data["status"] == "ignored"
