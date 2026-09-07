"""Test-scenario machinery.

Two ways to inject controlled behaviour for QA training:

  1. Global network mode set via `POST /api/test-controls/network-mode`
     (body: {"mode": "error500"}). Persists for all subsequent requests.
  2. Per-request override via the `X-Test-Scenario` header on any request.

Scenarios:
    slow-response  -> delay, then the normal response
    server-error   -> 500
    unauthorized   -> 401
    empty-tasks    -> empty list ([]) for GET requests
    invalid-json   -> malformed JSON body (200)
    conflict       -> 409
    normal         -> no effect

The control endpoints (/api/test*, /health, /docs, /openapi.json) are always
exempt so that a learner can always reset the mode even if it is misbehaving.
"""
from __future__ import annotations

from typing import Optional

from fastapi import Request

from .config import SLOW_DELAY_SECONDS

# Mapping of accepted scenario names (header or mode) to canonical mode.
_SCENARIOS = {
    "normal": "normal",
    "slow": "slow",
    "slow-response": "slow",
    "error500": "error500",
    "server-error": "error500",
    "unauthorized": "unauthorized",
    "empty": "empty",
    "empty-tasks": "empty",
    "invalid-json": "invalid-json",
    "conflict": "conflict",
}


class TestState:
    mode: str = "normal"


_state = TestState()


def get_network_mode() -> str:
    return _state.mode


def set_network_mode(mode: str) -> str:
    canonical = _SCENARIOS.get(mode)
    if canonical is None:
        raise ValueError(f"Unknown network mode: {mode}")
    _state.mode = canonical
    return canonical


def reset_network_mode() -> str:
    _state.mode = "normal"
    return _state.mode


def _is_exempt(path: str) -> bool:
    """Control/health/docs endpoints must never be affected by test modes."""
    return (
        path.startswith("/api/test")
        or path.startswith("/api/test-controls")
        or path in {"/health", "/docs", "/openapi.json", "/redoc"}
    )


def resolve_scenario(request: Request) -> Optional[str]:
    """Return the canonical scenario for this request, or None."""
    if _is_exempt(request.url.path):
        return None
    header = request.headers.get("x-test-scenario")
    if header:
        return _SCENARIOS.get(header.strip().lower())
    return _SCENARIOS.get(_state.mode) if _state.mode != "normal" else None


async def apply_scenario(scenario: str, call_next, request: Request):
    """Execute the scenario effect. Returns a Response or falls through."""
    import asyncio
    from fastapi.responses import JSONResponse, Response

    if scenario == "slow":
        await asyncio.sleep(SLOW_DELAY_SECONDS)
        return await call_next(request)
    if scenario == "error500":
        return JSONResponse({"detail": "Simulated server error"}, status_code=500)
    if scenario == "unauthorized":
        return JSONResponse({"detail": "Simulated unauthorized"}, status_code=401)
    if scenario == "conflict":
        return JSONResponse({"detail": "Simulated conflict"}, status_code=409)
    if scenario == "empty":
        if request.method == "GET":
            return JSONResponse([], status_code=200)
        return JSONResponse({}, status_code=200)
    if scenario == "invalid-json":
        return Response('{ "broken": ', media_type="application/json", status_code=200)
    return await call_next(request)
