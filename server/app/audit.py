"""Audit log helper.

Every mutation of a tracked entity writes a row to `audit_log` with before/after
snapshots. QA learners can then assert history after API calls.
"""
from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from .models import AuditLog


def log_event(
    db: Session,
    *,
    entity_type: str,
    entity_id: int,
    action: str,
    actor_id: int | None = None,
    before: dict[str, Any] | None = None,
    after: dict[str, Any] | None = None,
) -> AuditLog:
    entry = AuditLog(
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        actor_id=actor_id,
        before=before,
        after=after,
    )
    db.add(entry)
    db.flush()
    return entry
