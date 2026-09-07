"""ORM -> Pydantic conversion helpers.

A few response shapes include nested/derived fields (tags as a list of names,
assignee/reporter snapshots), so they are assembled here instead of relying on
`from_attributes` alone.
"""
from __future__ import annotations

from typing import Optional

from .models import AuditLog, Comment, Notification, ProjectMember, Tag, Task, User
from .schemas import (
    AuditOut,
    CommentOut,
    NotificationOut,
    ProjectMemberOut,
    ProjectOut,
    TagOut,
    TaskOut,
    UserOut,
)


def user_to_out(user: Optional[User]) -> Optional[UserOut]:
    if user is None:
        return None
    return UserOut.model_validate(user)


def task_to_out(task: Task) -> TaskOut:
    return TaskOut(
        id=task.id,
        title=task.title,
        description=task.description,
        status=task.status,
        priority=task.priority,
        project_id=task.project_id,
        assignee_id=task.assignee_id,
        reporter_id=task.reporter_id,
        due_date=task.due_date,
        tags=[t.name for t in task.tags],
        assignee=user_to_out(task.assignee),
        reporter=user_to_out(task.reporter),
        created_at=task.created_at,
        updated_at=task.updated_at,
    )


def comment_to_out(comment: Comment) -> CommentOut:
    return CommentOut(
        id=comment.id,
        task_id=comment.task_id,
        author_id=comment.author_id,
        author_name=comment.author.full_name if comment.author else None,
        body=comment.body,
        created_at=comment.created_at,
        updated_at=comment.updated_at,
    )


def tag_to_out(tag: Tag) -> TagOut:
    return TagOut.model_validate(tag)


def project_to_out(project) -> ProjectOut:
    return ProjectOut.model_validate(project)


def project_member_to_out(m: ProjectMember) -> ProjectMemberOut:
    return ProjectMemberOut(
        id=m.id,
        user_id=m.user_id,
        project_id=m.project_id,
        project_role=m.project_role,
        full_name=m.user.full_name,
        email=m.user.email,
    )


def notification_to_out(n: Notification) -> NotificationOut:
    return NotificationOut.model_validate(n)


def audit_to_out(entry: AuditLog) -> AuditOut:
    return AuditOut.model_validate(entry)
