"""Pytest fixtures for the example API test suite.

Placed at server/ so pytest adds this directory to sys.path and `app` is
importable. Run with:  cd server && pytest -q
"""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="session")
def client():
    """A TestClient that also seeds the database to the known baseline."""
    with TestClient(app) as c:
        c.post("/api/test/reset")
        yield c


@pytest.fixture(scope="session")
def admin_token(client) -> str:
    r = client.post(
        "/api/auth/login",
        json={"email": "admin@test.local", "password": "admin123"},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


@pytest.fixture(scope="session")
def member_token(client) -> str:
    r = client.post(
        "/api/auth/login",
        json={"email": "member@test.local", "password": "member123"},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


@pytest.fixture(scope="session")
def readonly_token(client) -> str:
    r = client.post(
        "/api/auth/login",
        json={"email": "readonly@test.local", "password": "readonly123"},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
