"""Application configuration.

All values can be overridden with environment variables, but the defaults are
chosen so that `./run.sh` works with zero configuration on a fresh checkout.
"""
from __future__ import annotations

import os
from pathlib import Path

# Repo root = parent of server/
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# The SQLite database lives in ./data/app.db relative to the repo root so that
# learners can open it directly with `sqlite3 data/app.db` or DB Browser.
DATA_DIR = Path(os.getenv("TASKFLOW_DATA_DIR", BASE_DIR / "data"))
DB_PATH = DATA_DIR / "app.db"
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DB_PATH}")

# JWT settings. The default secret is fine for a local, single-machine training
# server but should be changed for anything resembling production.
JWT_SECRET = os.getenv("JWT_SECRET", "taskflow-playground-secret-change-me")
JWT_ALG = os.getenv("JWT_ALG", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))  # 24h

# How long the "slow" test scenario delays a response (seconds).
SLOW_DELAY_SECONDS = float(os.getenv("SLOW_DELAY_SECONDS", "3"))

# Host/port the server binds to.
HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8000"))
