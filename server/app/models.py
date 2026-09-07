"""SQLAlchemy ORM models for the TaskFlow playground.

Tables:
    users, projects, project_members, tasks, comments, tags, task_tags,
    attachments, notifications, audit_log

The schema is intentionally "rich" so that QA learners have plenty of real
relationships to verify: foreign keys, cascades, many-to-many and history.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    Column,
    ForeignKey,
    String,
    Text,
    Integer,
    BigInteger,
    DateTime,
    Date,
    Boolean,
    JSON,
    Table,
    UniqueConstraint,
    CheckConstraint,
)
from sqlalchemy.orm import relationship, Mapped, mapped_column

from .database import Base


def _utcnow() -> datetime:
    """Naive UTC now (avoids the deprecation warning from datetime.utcnow)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


# many-to-many: task <-> tag
task_tags = Table(
    "task_tags",
    Base.metadata,
    Column("task_id", ForeignKey("tasks.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_utcnow, onupdate=_utcnow, nullable=False
    )


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False, default="")
    role: Mapped[str] = mapped_column(String(32), nullable=False, default="member")

    __table_args__ = (
        CheckConstraint(
            "role IN ('admin', 'manager', 'member', 'viewer')", name="ck_users_role"
        ),
    )

    memberships: Mapped[list["ProjectMember"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    assigned_tasks: Mapped[list["Task"]] = relationship(
        foreign_keys="Task.assignee_id", back_populates="assignee"
    )
    reported_tasks: Mapped[list["Task"]] = relationship(
        foreign_keys="Task.reporter_id", back_populates="reporter"
    )
    comments: Mapped[list["Comment"]] = relationship(
        back_populates="author", foreign_keys="Comment.author_id"
    )
    notifications: Mapped[list["Notification"]] = relationship(
        back_populates="user", cascade="all, delete-orphan",
        foreign_keys="Notification.user_id",
    )


class Project(TimestampMixin, Base):
    __tablename__ = "projects"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)

    owner: Mapped["User"] = relationship(foreign_keys=[owner_id])
    members: Mapped[list["ProjectMember"]] = relationship(
        back_populates="project", cascade="all, delete-orphan"
    )
    tasks: Mapped[list["Task"]] = relationship(
        back_populates="project", cascade="all, delete-orphan"
    )


class ProjectMember(Base):
    __tablename__ = "project_members"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    project_role: Mapped[str] = mapped_column(String(32), nullable=False, default="member")
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)

    project: Mapped["Project"] = relationship(back_populates="members", foreign_keys=[project_id])
    user: Mapped["User"] = relationship(back_populates="memberships", foreign_keys=[user_id])

    __table_args__ = (
        UniqueConstraint("project_id", "user_id", name="uq_project_user"),
        CheckConstraint(
            "project_role IN ('manager', 'member', 'viewer')", name="ck_projectmember_role"
        ),
    )


class Task(TimestampMixin, Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="todo")
    priority: Mapped[str] = mapped_column(String(32), nullable=False, default="medium")
    project_id: Mapped[int] = mapped_column(
        ForeignKey("projects.id", ondelete="CASCADE"), nullable=False
    )
    assignee_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reporter_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    due_date: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)

    project: Mapped["Project"] = relationship(back_populates="tasks", foreign_keys=[project_id])
    assignee: Mapped[Optional["User"]] = relationship(
        foreign_keys=[assignee_id], back_populates="assigned_tasks"
    )
    reporter: Mapped[Optional["User"]] = relationship(
        foreign_keys=[reporter_id], back_populates="reported_tasks"
    )
    comments: Mapped[list["Comment"]] = relationship(
        back_populates="task", cascade="all, delete-orphan",
        foreign_keys="Comment.task_id",
    )
    tags: Mapped[list["Tag"]] = relationship(secondary=task_tags, back_populates="tasks")
    attachments: Mapped[list["Attachment"]] = relationship(
        back_populates="task", cascade="all, delete-orphan",
        foreign_keys="Attachment.task_id",
    )
    notifications: Mapped[list["Notification"]] = relationship(
        back_populates="task", cascade="all, delete-orphan",
        foreign_keys="Notification.task_id",
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('todo', 'in_progress', 'done', 'cancelled')", name="ck_tasks_status"
        ),
        CheckConstraint(
            "priority IN ('low', 'medium', 'high', 'urgent')", name="ck_tasks_priority"
        ),
    )


class Comment(TimestampMixin, Base):
    __tablename__ = "comments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    task_id: Mapped[int] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False
    )
    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)

    task: Mapped["Task"] = relationship(back_populates="comments", foreign_keys=[task_id])
    author: Mapped[Optional["User"]] = relationship(
        back_populates="comments", foreign_keys=[author_id]
    )


class Tag(TimestampMixin, Base):
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    color: Mapped[str] = mapped_column(String(16), nullable=False, default="#888888")

    tasks: Mapped[list["Task"]] = relationship(secondary=task_tags, back_populates="tags")


class Attachment(TimestampMixin, Base):
    __tablename__ = "attachments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    task_id: Mapped[int] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    url: Mapped[str] = mapped_column(Text, nullable=False, default="")
    size: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    uploaded_by: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    task: Mapped["Task"] = relationship(back_populates="attachments", foreign_keys=[task_id])


class Notification(TimestampMixin, Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(64), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False, default="")
    payload: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    task_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"), nullable=True
    )

    user: Mapped["User"] = relationship(back_populates="notifications", foreign_keys=[user_id])
    task: Mapped[Optional["Task"]] = relationship(
        back_populates="notifications", foreign_keys=[task_id]
    )


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    entity_type: Mapped[str] = mapped_column(String(64), nullable=False)
    entity_id: Mapped[int] = mapped_column(Integer, nullable=False)
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    actor_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    before: Mapped[dict] = mapped_column(JSON, nullable=True)
    after: Mapped[dict] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
