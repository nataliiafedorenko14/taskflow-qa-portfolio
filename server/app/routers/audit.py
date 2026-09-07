from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import AuditLog, User
from ..permissions import require_role
from ..schemas import AuditOut
from ..serializers import audit_to_out

router = APIRouter(prefix="/api/audit", tags=["audit"])


@router.get("", response_model=list[AuditOut])
def list_audit(
    db: Session = Depends(get_db),
    _: User = Depends(require_role("admin", "manager")),
    entity_type: Optional[str] = None,
    entity_id: Optional[int] = None,
    limit: int = 100,
):
    query = db.query(AuditLog)
    if entity_type is not None:
        query = query.filter(AuditLog.entity_type == entity_type)
    if entity_id is not None:
        query = query.filter(AuditLog.entity_id == entity_id)
    rows = query.order_by(AuditLog.id.desc()).limit(limit).all()
    return [audit_to_out(a) for a in rows]
