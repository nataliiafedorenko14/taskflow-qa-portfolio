"""Role- and project-based access control helpers.

Access model:
  * admin  -> everything, every project
  * manager-> edit tasks in projects they are a member of
  * member  -> edit tasks they reported or are assigned, in their projects
  * viewer  -> read only (used for negative RBAC tests)
"""
from __future__ import annotations

from fastapi import HTTPException, Depends
from sqlalchemy.orm import Session

from .models import Project, ProjectMember, Task, User
from .security import get_current_user


def require_role(*roles: str):
    """FastAPI dependency: allow only users whose global role is in `roles`."""

    def _dep(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail=f"Requires one of roles: {', '.join(roles)}")
        return user

    return _dep


def get_membership(db: Session, project_id: int, user_id: int) -> ProjectMember | None:
    return (
        db.query(ProjectMember)
        .filter_by(project_id=project_id, user_id=user_id)
        .first()
    )


def get_project_for_user(db: Session, project_id: int, user: User) -> Project:
    """Return the project if it exists and the user may see it, else 404/403."""
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found")
    if user.role != "admin" and get_membership(db, project_id, user.id) is None:
        raise HTTPException(status_code=403, detail="Not a member of this project")
    return project


def require_project_role(db: Session, project_id: int, user: User, *roles: str) -> ProjectMember:
    """Ensure the user has one of the given project roles (admin bypasses)."""
    if user.role == "admin":
        membership = get_membership(db, project_id, user.id)
        # Admin may act even without an explicit membership row.
        return membership  # type: ignore[return-value]
    membership = get_membership(db, project_id, user.id)
    if membership is None:
        raise HTTPException(status_code=403, detail="Not a member of this project")
    if membership.project_role not in roles:
        raise HTTPException(
            status_code=403,
            detail=f"Requires project role: {', '.join(roles)}",
        )
    return membership


def can_edit_task(db: Session, user: User, task: Task) -> bool:
    if user.role == "admin":
        return True
    membership = get_membership(db, task.project_id, user.id)
    if membership is None:
        return False
    if membership.project_role == "manager":
        return True
    if membership.project_role == "member":
        return task.assignee_id == user.id or task.reporter_id == user.id
    return False  # viewer


def get_task_for_user(db: Session, task_id: int, user: User) -> Task:
    """Return the task if it exists and the user may see it, else 404/403."""
    task = db.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    if user.role != "admin" and get_membership(db, task.project_id, user.id) is None:
        raise HTTPException(status_code=403, detail="Not a member of this task's project")
    return task


def resolve_assignee(db: Session, project_id: int, assignee_id: int | None) -> int | None:
    """An assignee must be a member of the task's project (or None to clear)."""
    if assignee_id is None:
        return None
    membership = get_membership(db, project_id, assignee_id)
    if membership is None:
        raise HTTPException(
            status_code=400,
            detail="Assignee is not a member of this project",
        )
    return assignee_id
