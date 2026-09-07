"""Database engine, session factory and declarative base.

Uses SQLite by default (see config.DATABASE_URL). Foreign-key enforcement is
enabled per-connection so that ON DELETE CASCADE behaves as learners expect.
"""
from __future__ import annotations

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from .config import DATABASE_URL, DATA_DIR

# Make sure the data directory exists before the engine tries to connect.
DATA_DIR.mkdir(parents=True, exist_ok=True)

# `check_same_thread=False` lets FastAPI's threadpool serve requests from the
# same connection pool; `timeout` makes concurrent writes wait instead of
# raising "database is locked" immediately (useful for the race-condition test).
connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False, "timeout": 30}

engine = create_engine(DATABASE_URL, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""


def get_db():
    """FastAPI dependency that yields a scoped SQLAlchemy session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create all tables defined on the metadata. Safe to call repeatedly."""
    Base.metadata.create_all(bind=engine)


# Enable SQLite foreign keys (off by default) so ON DELETE CASCADE works.
if DATABASE_URL.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def _enable_sqlite_fk(dbapi_connection, _record):  # pragma: no cover
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()
