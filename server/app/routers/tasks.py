from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, exists, or_
from sqlalchemy.orm import Session

from ..audit import log_event
from ..database import get_db
from ..models import Notification, Tag, Task, User, task_tags
from ..permissions import (
    can_edit_task,
    get_project_for_user,
    get_task_for_user,
    resolve_assignee,
)
from ..schemas import TaskCreate, TaskOut, TaskPage, TaskUpdate
from ..serializers import task_to_out
from ..security import get_current_user

router = APIRouter(prefix="/api", tags=["tasks"])

SORT_FIELDS = {
    "created_at": Task.created_at,
    "updated_at": Task.updated_at,
    "title": Task.title,
    "due_date": Task.due_date,
}


def _snapshot(task: Task) -> dict:
    return {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "status": task.status,
        "priority": task.priority,
        "project_id": task.project_id,
        "assignee_id": task.assignee_id,
        "reporter_id": task.reporter_id,
        "due_date": task.due_date.isoformat() if task.due_date else None,
        "tags": [t.name for t in task.tags],
    }


def _sync_tags(db: Session, task: Task, names: list[str]) -> None:
    """Attach tags by name, creating any that do not exist yet."""
    task.tags = []
    for name in names:
        if not name:
            continue
        tag = db.query(Tag).filter_by(name=name).first()
        if tag is None:
            tag = Tag(name=name, color="#888888")
            db.add(tag)
            db.flush()
        if tag not in task.tags:
            task.tags.append(tag)


def _notify(db: Session, user_id: Optional[int], ntype: str, message: str, task: Task) -> None:
    if user_id is None:
        return
    db.add(Notification(
        user_id=user_id,
        type=ntype,
        message=message,
        payload={"task_id": task.id, "title": task.title},
        read=False,
        task_id=task.id,
    ))


@router.post("/projects/{project_id}/tasks", response_model=TaskOut, status_code=201)
def create_task(
    project_id: int,
    payload: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_project_for_user(db, project_id, current_user)
    assignee_id = resolve_assignee(db, project_id, payload.assignee_id)
    task = Task(
        title=payload.title,
        description=payload.description,
        status=payload.status,
        priority=payload.priority,
        project_id=project_id,
        assignee_id=assignee_id,
        reporter_id=current_user.id,
        due_date=payload.due_date,
    )
    db.add(task)
    db.flush()
    _sync_tags(db, task, payload.tags)
    log_event(
        db,
        entity_type="task",
        entity_id=task.id,
        action="create",
        actor_id=current_user.id,
        before=None,
        after=_snapshot(task),
    )
    if assignee_id is not None and assignee_id != current_user.id:
        _notify(db, assignee_id, "task_assigned", "A task was assigned to you.", task)
    db.commit()
    db.refresh(task)
    return task_to_out(task)


@router.get("/tasks", response_model=TaskPage)
def list_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    status: Optional[str] = None,
    priority: Optional[str] = None,
    assignee_id: Optional[int] = None,
    project_id: Optional[int] = None,
    tag: Optional[str] = None,
    q: Optional[str] = None,
    sort: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    query = db.query(Task)

    # Scope to projects the user may see (admins see all).
    from ..models import Project, ProjectMember
    if current_user.role != "admin":
        member_project_ids = [
            pm.project_id
            for pm in db.query(ProjectMember).filter_by(user_id=current_user.id).all()
        ]
        if project_id is not None and project_id not in member_project_ids:
            raise HTTPException(status_code=403, detail="Not a member of this project")
        query = query.filter(Task.project_id.in_(member_project_ids))
    elif project_id is not None:
        if db.get(Project, project_id) is None:
            raise HTTPException(status_code=404, detail="Project not found")
        query = query.filter(Task.project_id == project_id)

    if status is not None:
        query = query.filter(Task.status == status)
    if priority is not None:
        query = query.filter(Task.priority == priority)
    if assignee_id is not None:
        query = query.filter(Task.assignee_id == assignee_id)
    if q:
        like = f"%{q}%"
        query = query.filter(or_(Task.title.ilike(like), Task.description.ilike(like)))
    if tag:
        query = query.filter(
            exists().where(and_(task_tags.c.task_id == Task.id, task_tags.c.tag_id == Tag.id, Tag.name == tag))
        )

    sort_param = sort or "-created_at"
    descending = sort_param.startswith("-")
    field = sort_param.lstrip("-")
    column = SORT_FIELDS.get(field, Task.created_at)
    query = query.order_by(column.desc() if descending else column.asc())

    total = query.count()
    offset = (page - 1) * page_size
    items = query.offset(offset).limit(page_size).all()
    return TaskPage(
        items=[task_to_out(t) for t in items],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = get_task_for_user(db, task_id, current_user)
    return task_to_out(task)


@router.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(
    task_id: int,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = get_task_for_user(db, task_id, current_user)
    if not can_edit_task(db, current_user, task):
        raise HTTPException(status_code=403, detail="You cannot edit this task")

    before = _snapshot(task)
    changed = False

    if payload.title is not None and payload.title != task.title:
        task.title = payload.title
        changed = True
    if payload.description is not None and payload.description != task.description:
        task.description = payload.description
        changed = True
    if payload.priority is not None and payload.priority != task.priority:
        task.priority = payload.priority
        changed = True
    if payload.status is not None and payload.status != task.status:
        old_status = task.status
        task.status = payload.status
        changed = True
        # notify reporter + assignee about the status change
        _notify(db, task.reporter_id, "status_changed", f"Task status changed to {payload.status}.", task)
        if task.assignee_id:
            _notify(db, task.assignee_id, "status_changed", f"Task status changed to {payload.status}.", task)
    if payload.due_date is not None and payload.due_date != task.due_date:
        task.due_date = payload.due_date
        changed = True
    if payload.assignee_id is not None and payload.assignee_id != task.assignee_id:
        new_assignee = resolve_assignee(db, task.project_id, payload.assignee_id)
        task.assignee_id = new_assignee
        changed = True
        if new_assignee is not None and new_assignee != current_user.id:
            _notify(db, new_assignee, "task_assigned", "A task was assigned to you.", task)
    if payload.tags is not None:
        _sync_tags(db, task, payload.tags)
        changed = True

    if not changed:
        return task_to_out(task)

    after = _snapshot(task)
    log_event(
        db,
        entity_type="task",
        entity_id=task.id,
        action="update",
        actor_id=current_user.id,
        before=before,
        after=after,
    )
    db.commit()
    db.refresh(task)
    return task_to_out(task)


@router.delete("/tasks/{task_id}", status_code=204)
def delete_task(
    task_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = get_task_for_user(db, task_id, current_user)
    if not can_edit_task(db, current_user, task):
        raise HTTPException(status_code=403, detail="You cannot delete this task")
    before = _snapshot(task)
    log_event(
        db,
        entity_type="task",
        entity_id=task.id,
        action="delete",
        actor_id=current_user.id,
        before=before,
        after=None,
    )
    db.delete(task)
    db.commit()
