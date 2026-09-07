"""Pydantic schemas (request/response validation).

These also drive the auto-generated OpenAPI/Swagger at /docs, so they double as
the contract learners test against.
"""
from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


# --- enums -----------------------------------------------------------------

class Role(str, Enum):
    admin = "admin"
    manager = "manager"
    member = "member"
    viewer = "viewer"


class ProjectRole(str, Enum):
    manager = "manager"
    member = "member"
    viewer = "viewer"


class TaskStatus(str, Enum):
    todo = "todo"
    in_progress = "in_progress"
    done = "done"
    cancelled = "cancelled"


class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"
    urgent = "urgent"


# --- auth / users ----------------------------------------------------------

class UserCreate(BaseModel):
    email: str = Field(..., examples=["member@test.local"])
    password: str = Field(..., min_length=6, max_length=128)
    full_name: str = Field("", max_length=255, alias="full_name", examples=["Jane Doe"])

    @field_validator("email")
    @classmethod
    def _valid_email(cls, v: str) -> str:
        v = v.strip().lower()
        if "@" not in v or " " in v:
            raise ValueError("Invalid email address")
        return v


class UserLogin(BaseModel):
    email: str = Field(..., examples=["member@test.local"])
    password: str = Field(...)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: str
    full_name: str
    role: Role


class UserUpdate(BaseModel):
    role: Optional[Role] = None
    full_name: Optional[str] = Field(None, max_length=255)


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


# --- projects --------------------------------------------------------------

class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str = Field("", max_length=2000)


class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=2000)


class ProjectMemberOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    project_id: int
    project_role: ProjectRole
    full_name: str
    email: str


class ProjectOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    description: str
    owner_id: int
    created_at: datetime
    updated_at: datetime


class AddMember(BaseModel):
    user_id: int
    project_role: ProjectRole = ProjectRole.member


# --- tasks -----------------------------------------------------------------

class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: str = Field("", max_length=5000)
    status: TaskStatus = TaskStatus.todo
    priority: Priority = Priority.medium
    assignee_id: Optional[int] = None
    due_date: Optional[date] = None
    tags: list[str] = Field(default_factory=list)


class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=5000)
    status: Optional[TaskStatus] = None
    priority: Optional[Priority] = None
    assignee_id: Optional[int] = None
    due_date: Optional[date] = None
    tags: Optional[list[str]] = None


class TaskOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    description: str
    status: TaskStatus
    priority: Priority
    project_id: int
    assignee_id: Optional[int] = None
    reporter_id: Optional[int] = None
    due_date: Optional[date] = None
    tags: list[str] = Field(default_factory=list)
    assignee: Optional[UserOut] = None
    reporter: Optional[UserOut] = None
    created_at: datetime
    updated_at: datetime


class TaskPage(BaseModel):
    items: list[TaskOut]
    total: int
    page: int
    page_size: int


# --- comments --------------------------------------------------------------

class CommentCreate(BaseModel):
    body: str = Field(..., min_length=1, max_length=5000)


class CommentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    task_id: int
    author_id: Optional[int] = None
    author_name: Optional[str] = None
    body: str
    created_at: datetime
    updated_at: datetime


# --- tags ------------------------------------------------------------------

class TagCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=64)
    color: str = Field("#888888", max_length=16)


class TagOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    color: str


class AttachTag(BaseModel):
    tags: list[str] = Field(default_factory=list)


# --- notifications ---------------------------------------------------------

class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    type: str
    message: str
    read: bool
    task_id: Optional[int] = None
    created_at: datetime


class NotificationMark(BaseModel):
    read: bool = True


# --- audit -----------------------------------------------------------------

class AuditOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    entity_type: str
    entity_id: int
    action: str
    actor_id: Optional[int] = None
    before: Optional[dict] = None
    after: Optional[dict] = None
    created_at: datetime


# --- test controls ---------------------------------------------------------

class NetworkMode(str, Enum):
    normal = "normal"
    slow = "slow"
    error500 = "error500"
    unauthorized = "unauthorized"
    empty = "empty"
    invalid_json = "invalid-json"
    conflict = "conflict"


class NetworkModeRequest(BaseModel):
    mode: NetworkMode


class SeedUser(BaseModel):
    email: str
    password: str
    role: Role
    purpose: str


class SeedInfo(BaseModel):
    users: list[SeedUser]
    notes: list[str]


Token.model_rebuild()
