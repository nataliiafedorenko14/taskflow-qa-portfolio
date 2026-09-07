from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Comment, User
from ..permissions import get_task_for_user
from ..schemas import CommentCreate, CommentOut
from ..serializers import comment_to_out
from ..security import get_current_user

router = APIRouter(prefix="/api/tasks", tags=["comments"])


@router.get("/{task_id}/comments", response_model=list[CommentOut])
def list_comments(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_task_for_user(db, task_id, current_user)  # access check (404/403)
    rows = db.query(Comment).filter_by(task_id=task_id).order_by(Comment.id).all()
    return [comment_to_out(c) for c in rows]


@router.post("/{task_id}/comments", response_model=CommentOut, status_code=201)
def create_comment(
    task_id: int,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = get_task_for_user(db, task_id, current_user)
    comment = Comment(task_id=task.id, author_id=current_user.id, body=payload.body)
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return comment_to_out(comment)
