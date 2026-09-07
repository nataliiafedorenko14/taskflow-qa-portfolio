"""Tiny CLI used by ./run.sh to initialise / reset the database.

    python -m app.cli init   # create tables, seed only if empty (idempotent)
    python -m app.cli reset  # wipe + re-seed to the known baseline
"""
from __future__ import annotations

import argparse

from .database import SessionLocal, init_db
from .models import User
from .seed import seed_database


def cmd_init() -> None:
    init_db()
    db = SessionLocal()
    try:
        if db.query(User).count() == 0:
            seed_database(db)
            print("Seeded a fresh database.")
        else:
            print("Database already has data; skipping seed. (Use `reset` to reseed.)")
    finally:
        db.close()


def cmd_reset() -> None:
    init_db()
    db = SessionLocal()
    try:
        summary = seed_database(db)
        print(f"Database reset to seed baseline: {summary}")
    finally:
        db.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="TaskFlow DB helper.")
    parser.add_argument("command", choices=["init", "reset"])
    args = parser.parse_args()
    if args.command == "init":
        cmd_init()
    else:
        cmd_reset()


if __name__ == "__main__":
    main()
