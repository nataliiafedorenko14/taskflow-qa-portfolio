#!/usr/bin/env bash
#
# One-command local launch for the TaskFlow QA playground.
#
#   ./run.sh            # create venv, install deps, init/seed DB, serve on :8000
#   ./run.sh --reset     # re-seed the database, then start the server
#   ./run.sh --clean     # delete the DB file and re-seed, then start
#   ./run.sh --port N    # serve on port N (also honours $PORT)
#   ./run.sh test        # run the example API test suite (pytest)
#
# Requires only `python3` (ships with macOS Command Line Tools).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
VENV="$SCRIPT_DIR/.venv"
PYBIN="$VENV/bin/python"

PORT="${PORT:-8000}"
RESET=0
CLEAN=0
ACTION="serve"

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift;;
    --clean) CLEAN=1; RESET=1; shift;;
    --port) PORT="$2"; shift 2;;
    --help|-h) ACTION="help"; shift;;
    test) ACTION="test"; shift;;
    *) echo "Unknown argument: $1" >&2; exit 2;;
  esac
done

if [ "$ACTION" = "help" ]; then
  sed -n '3,13p' "$0"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is not installed." >&2
  echo "Install the Command Line Tools:  xcode-select --install" >&2
  exit 1
fi

if [ ! -d "$VENV" ]; then
  echo ">> Creating virtual environment (.venv)"
  python3 -m venv "$VENV"
fi

echo ">> Installing dependencies (requirements.txt)"
"$VENV/bin/pip" install -q --upgrade pip >/dev/null
"$VENV/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt"

if [ "$CLEAN" = 1 ]; then
  echo ">> Removing data/app.db"
  rm -f "$SCRIPT_DIR/data/app.db"
fi

echo ">> Initialising database"
( cd "$SCRIPT_DIR/server" && "$PYBIN" -m app.cli $([ "$RESET" = 1 ] && echo reset || echo init) )

if [ "$ACTION" = "test" ]; then
  echo ">> Running example API tests"
  ( cd "$SCRIPT_DIR/server" && "$VENV/bin/pytest" -q )
  exit 0
fi

cat <<EOF

================================================================
  TaskFlow QA Playground is starting.
  Swagger UI :  http://localhost:${PORT}/docs
  OpenAPI    :  http://localhost:${PORT}/openapi.json
  Reset DB   :  POST http://localhost:${PORT}/api/test/reset
  Inspect DB :  sqlite3 $SCRIPT_DIR/data/app.db
  Seed creds :  GET  http://localhost:${PORT}/api/test/seed-info
================================================================

Press Ctrl+C to stop.

EOF

cd "$SCRIPT_DIR/server"
exec "$VENV/bin/uvicorn" app.main:app --host 127.0.0.1 --port "$PORT"
