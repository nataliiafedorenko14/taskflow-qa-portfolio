"""Test-control endpoints.

These are the heart of the playground for QA: deterministic reset + known
credentials + a way to switch the whole server into error/network modes
without breaking the real stand.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import SessionLocal, get_db
from ..schemas import NetworkMode, NetworkModeRequest, SeedInfo, SeedUser
from ..seed import SEED_USERS, seed_database
from ..test_controls import get_network_mode, reset_network_mode, set_network_mode

router = APIRouter(prefix="/api", tags=["test-controls"])

# Build the public seed-info (including the demo passwords) for learners.
_SEED_USER_INFO = {
    "admin@test.local": ("admin", "manage projects, users and members"),
    "manager@test.local": ("manager", "create and assign tasks"),
    "member@test.local": ("member", "work on own tasks"),
    "readonly@test.local": ("viewer", "read-only; used for negative RBAC (403) checks"),
    "empty@test.local": ("member", "a user with no projects"),
}


@router.get("/test/seed-info", response_model=SeedInfo)
def seed_info():
    users = []
    for email, password, _role, _name in SEED_USERS:
        role, purpose = _SEED_USER_INFO[email]
        users.append(SeedUser(email=email, password=password, role=role, purpose=purpose))
    return SeedInfo(
        users=users,
        notes=[
            "These passwords are for local training only; never reuse them.",
            "Use POST /api/test/reset to return the database to this baseline.",
            "Use POST /api/test-controls/network-mode to inject error/network scenarios.",
            "Inspect the database directly with: sqlite3 data/app.db",
        ],
    )


@router.post("/test/reset", response_model=dict)
def reset():
    """Wipe and re-seed the database. No auth, for use in CI/automation."""
    db = SessionLocal()
    try:
        summary = seed_database(db)
    finally:
        db.close()
    return {"reset": True, "summary": summary}


@router.post("/test-controls/network-mode", response_model=dict)
def set_network_mode_endpoint(payload: NetworkModeRequest):
    mode = set_network_mode(payload.mode)
    return {"mode": mode}


@router.post("/test-controls/network-mode/reset", response_model=dict)
def reset_network_mode_endpoint():
    return {"mode": reset_network_mode()}


@router.get("/test-controls/network-mode", response_model=dict)
def get_network_mode_endpoint():
    return {"mode": get_network_mode()}