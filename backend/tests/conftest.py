"""Configuration pytest : base SQLite isolée et client de test."""

import os
import tempfile
from pathlib import Path

DB_FILE = Path(tempfile.gettempdir()) / "miam_pytest.db"
if DB_FILE.exists():
    DB_FILE.unlink()

os.environ["DATABASE_URL"] = f"sqlite:///{DB_FILE}"
os.environ["SEED_DATA"] = "1"
os.environ["SECRET_KEY"] = "test-secret-key"

import pytest
from fastapi.testclient import TestClient

from app.main import app

DEMO_PASSWORD = "demo1234"


def login(client: TestClient, email: str, password: str = DEMO_PASSWORD) -> str:
    response = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def tokens(client):
    return {
        role: login(client, f"{role}@miam.app")
        for role in ("admin", "partner", "courier", "client")
    }
