from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Tag, Task, User
from ..permissions import can_edit_task, get_task_for_user
from ..schemas import AttachTag, TagCreate, TagOut, TaskOut
from ..serializers import tag_to_out, task_to_out
from ..security import get_current_user

router = APIRouter(prefix="/api", tags=["tags"])


@router.get("/tags", response_model=list[TagOut])
def list_tags(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return [tag_to_out(t) for t in db.query(Tag).order_by(Tag.name).all()]


@router.post("/tags", response_model=TagOut, status_code=201)
def create_tag(
    payload: TagCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    existing = db.query(Tag).filter_by(name=payload.name).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Tag already exists")
    tag = Tag(name=payload.name, color=payload.color)
    db.add(tag)
    db.commit()
    db.refresh(tag)
    return tag_to_out(tag)


@router.post("/tasks/{task_id}/tags", response_model=TaskOut)
def attach_tags(
    task_id: int,
    payload: AttachTag,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = get_task_for_user(db, task_id, current_user)
    if not can_edit_task(db, current_user, task):
        raise HTTPException(status_code=403, detail="You cannot edit this task")
    for name in payload.tags:
        if not name:
            continue
        tag = db.query(Tag).filter_by(name=name).first()
        if tag is None:
            tag = Tag(name=name, color="#888888")
            db.add(tag)
            db.flush()
        if tag not in task.tags:
            task.tags.append(tag)
    db.commit()
    db.refresh(task)
    return task_to_out(task)
