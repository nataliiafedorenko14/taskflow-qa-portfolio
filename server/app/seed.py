"""Idempotent seed data.

`seed_database(db)` wipes everything and inserts a deterministic, predictable
dataset so that every QA learner starts from the exact same state and so that
`POST /api/test/reset` always returns to a known baseline.

Preset users (see /api/test/seed-info):
    admin@test.local     / admin123      -> admin   (manage everything)
    manager@test.local   / manager123    -> manager (create & assign tasks)
    member@test.local    / member123     -> member  (work on own tasks)
    readonly@test.local / readonly123   -> viewer  (read-only, 403 on writes)
    empty@test.local     / empty123      -> member  (no projects at all)
"""
from __future__ import annotations

from datetime import date

from sqlalchemy.orm import Session

from .models import (
    AuditLog,
    Attachment,
    Comment,
    Notification,
    Project,
    ProjectMember,
    Tag,
    Task,
    User,
)
from .security import hash_password


SEED_USERS = [
    ("admin@test.local", "admin123", "admin", "QA Admin"),
    ("manager@test.local", "manager123", "manager", "Team Manager"),
    ("member@test.local", "member123", "member", "Team Member"),
    ("readonly@test.local", "readonly123", "viewer", "Read Only"),
    ("empty@test.local", "empty123", "member", "No Projects"),
]

SEED_TAGS = [
    ("ios", "#0a84ff"),
    ("automation", "#34c759"),
    ("bug", "#ff453a"),
    ("feature", "#ffd60a"),
    ("api", "#bf5af2"),
    ("ui", "#64d2ff"),
]


def _delete_all(db: Session) -> None:
    # Order matters: children first, then parents.
    db.query(AuditLog).delete()
    db.query(Notification).delete()
    db.query(Attachment).delete()
    db.query(Comment).delete()
    db.query(Task).delete()
    db.query(ProjectMember).delete()
    db.query(Project).delete()
    db.query(Tag).delete()
    db.query(User).delete()
    db.commit()


def seed_database(db: Session) -> dict:
    """Reset the database to the seed baseline. Returns a small summary."""
    _delete_all(db)

    users: dict[str, User] = {}
    for email, password, role, full_name in SEED_USERS:
        u = User(
            email=email,
            password_hash=hash_password(password),
            full_name=full_name,
            role=role,
        )
        db.add(u)
    db.flush()
    for email, _pw, _role, _fn in SEED_USERS:
        users[email] = db.query(User).filter_by(email=email).one()

    admin = users["admin@test.local"]
    manager = users["manager@test.local"]
    member = users["member@test.local"]
    readonly = users["readonly@test.local"]
    # empty@test.local is intentionally left with no memberships.

    tags: dict[str, Tag] = {}
    for name, color in SEED_TAGS:
        t = Tag(name=name, color=color)
        db.add(t)
    db.flush()
    for name, _color in SEED_TAGS:
        tags[name] = db.query(Tag).filter_by(name=name).one()

    # --- projects ----------------------------------------------------------
    p1 = Project(name="Mobile QA Automation", description="Main playground project.", owner_id=admin.id)
    p2 = Project(name="Backend Refactor", description="Server cleanup work.", owner_id=admin.id)
    p3 = Project(name="Onboarding", description="Newcomer tasks.", owner_id=manager.id)
    db.add_all([p1, p2, p3])
    db.flush()

    def add_member(project, user, project_role):
        db.add(ProjectMember(project_id=project.id, user_id=user.id, project_role=project_role))

    add_member(p1, admin, "manager")
    add_member(p1, manager, "manager")
    add_member(p1, member, "member")
    add_member(p2, admin, "manager")
    add_member(p2, manager, "manager")  # member NOT in p2 -> 403 for member
    add_member(p3, manager, "manager")
    add_member(p3, readonly, "viewer")  # member NOT in p3 -> 403 for member
    db.flush()

    # --- tasks -------------------------------------------------------------
    overdue = date(2026, 1, 15)
    upcoming = date(2026, 12, 31)
    statuses = ["todo", "in_progress", "done", "cancelled"]
    priorities = ["low", "medium", "high", "urgent"]
    tag_names = [n for n, _ in SEED_TAGS]

    # 25 tasks in p1 for pagination practice.
    for i in range(1, 26):
        status = statuses[i % len(statuses)]
        priority = priorities[i % len(priorities)]
        if i % 5 == 0:
            due = overdue
        elif i % 2 == 0:
            due = upcoming
        else:
            due = None
        assignee = member.id if (i % 3 != 0) else None
        reporter = manager.id
        task = Task(
            title=f"Task {i}: verify {['login','search','filters','pagination','comments'][i % 5]} flow",
            description=f"Description for task {i}. Add automated checks.",
            status=status,
            priority=priority,
            project_id=p1.id,
            assignee_id=assignee,
            reporter_id=reporter,
            due_date=due,
        )
        # attach 1-2 tags deterministically
        t1 = tags[tag_names[i % len(tag_names)]]
        db.add(task)
        db.flush()
        task.tags.append(t1)
        if i % 2 == 0:
            task.tags.append(tags[tag_names[(i + 2) % len(tag_names)]])

    # a couple of tasks in p2 (member cannot see these)
    for i in range(1, 4):
        db.add(Task(
            title=f"Backend task {i}",
            description="Refactor area.",
            status=statuses[i % len(statuses)],
            priority=priorities[i % len(priorities)],
            project_id=p2.id,
            assignee_id=manager.id,
            reporter_id=admin.id,
            due_date=upcoming,
        ))
    db.flush()

    # tasks in p3 (member cannot see these; readonly is a viewer here)
    for i in range(1, 3):
        db.add(Task(
            title=f"Onboarding task {i}",
            description="Setup steps.",
            status="todo",
            priority="medium",
            project_id=p3.id,
            assignee_id=readonly.id,
            reporter_id=manager.id,
            due_date=upcoming,
        ))
    db.flush()

    # --- comments ----------------------------------------------------------
    first_task = db.query(Task).filter_by(project_id=p1.id).order_by(Task.id).first()
    if first_task is not None:
        db.add(Comment(task_id=first_task.id, author_id=member.id, body="Started looking into this."))
        db.add(Comment(task_id=first_task.id, author_id=manager.id, body="Great, keep me posted."))
    db.flush()

    # --- notifications ------------------------------------------------------
    if first_task is not None:
        db.add(Notification(
            user_id=member.id,
            type="task_assigned",
            message="You have been assigned a new task.",
            payload={"task_id": first_task.id, "title": first_task.title},
            read=False,
            task_id=first_task.id,
        ))
    db.flush()

    # --- audit log (a couple of seed entries) -------------------------------
    if first_task is not None:
        db.add(AuditLog(
            entity_type="task",
            entity_id=first_task.id,
            action="create",
            actor_id=manager.id,
            before=None,
            after={"title": first_task.title, "status": first_task.status, "project_id": first_task.project_id},
        ))
    db.commit()

    return {
        "users": len(SEED_USERS),
        "projects": 3,
        "tasks": db.query(Task).count(),
        "comments": db.query(Comment).count(),
        "tags": len(SEED_TAGS),
    }
