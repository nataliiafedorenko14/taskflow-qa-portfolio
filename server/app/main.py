"""FastAPI application entrypoint.

Run with:  uvicorn app.main:app --reload
(see ../run.sh for the zero-config one-liner.)
"""
from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from .database import SessionLocal, init_db
from .models import User
from .routers import audit, auth, comments, notifications, projects, tags, tasks, test, users
from .seed import seed_database
from .test_controls import apply_scenario, resolve_scenario


@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    # Seed automatically on a fresh/empty database; restarts preserve data.
    db = SessionLocal()
    try:
        if db.query(User).count() == 0:
            seed_database(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title="TaskFlow QA Playground API",
    description=(
        "REST API for the TaskFlow task-tracker training playground. "
        "Use the test-control endpoints to inject error/network scenarios and "
        "to reset the database to a known baseline."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# CORS is harmless for the iOS app (URLSession ignores it) but convenient for
# any browser-based tools pointed at the playground.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def test_scenario_middleware(request: Request, call_next):
    scenario = resolve_scenario(request)
    if scenario:
        return await apply_scenario(scenario, call_next, request)
    return await call_next(request)


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(projects.router)
app.include_router(tasks.router)
app.include_router(comments.router)
app.include_router(tags.router)
app.include_router(notifications.router)
app.include_router(audit.router)
app.include_router(test.router)
