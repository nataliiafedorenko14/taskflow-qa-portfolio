from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Notification, User
from ..schemas import NotificationMark, NotificationOut
from ..serializers import notification_to_out
from ..security import get_current_user

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationOut])
def list_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    unread_only: bool = False,
):
    query = db.query(Notification).filter_by(user_id=current_user.id)
    if unread_only:
        query = query.filter_by(read=False)
    rows = query.order_by(Notification.created_at.desc()).all()
    return [notification_to_out(n) for n in rows]


@router.patch("/{notification_id}", response_model=NotificationOut)
def mark_notification(
    notification_id: int,
    payload: NotificationMark,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    n = db.get(Notification, notification_id)
    if n is None or n.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.read = payload.read
    db.commit()
    db.refresh(n)
    return notification_to_out(n)


@router.post("/read-all", response_model=dict)
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = db.query(Notification).filter_by(user_id=current_user.id, read=False).all()
    for n in rows:
        n.read = True
    db.commit()
    return {"updated": len(rows)}
