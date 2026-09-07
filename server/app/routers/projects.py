from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Project, ProjectMember, Task, User
from ..permissions import (
    get_membership,
    get_project_for_user,
    require_project_role,
)
from ..schemas import AddMember, ProjectCreate, ProjectMemberOut, ProjectOut, ProjectUpdate, TaskOut
from ..serializers import project_member_to_out, project_to_out, task_to_out
from ..security import get_current_user

router = APIRouter(prefix="/api/projects", tags=["projects"])


@router.get("", response_model=list[ProjectOut])
def list_projects(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role == "admin":
        rows = db.query(Project).order_by(Project.id).all()
    else:
        rows = (
            db.query(Project)
            .join(ProjectMember, ProjectMember.project_id == Project.id)
            .filter(ProjectMember.user_id == current_user.id)
            .order_by(Project.id)
            .all()
        )
    return [project_to_out(p) for p in rows]


@router.post("", response_model=ProjectOut, status_code=201)
def create_project(
    payload: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = Project(name=payload.name, description=payload.description, owner_id=current_user.id)
    db.add(project)
    db.flush()
    db.add(ProjectMember(project_id=project.id, user_id=current_user.id, project_role="manager"))
    db.commit()
    db.refresh(project)
    return project_to_out(project)


@router.get("/{project_id}", response_model=ProjectOut)
def get_project(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return project_to_out(get_project_for_user(db, project_id, current_user))


@router.patch("/{project_id}", response_model=ProjectOut)
def update_project(
    project_id: int,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = get_project_for_user(db, project_id, current_user)
    require_project_role(db, project_id, current_user, "manager")
    if payload.name is not None:
        project.name = payload.name
    if payload.description is not None:
        project.description = payload.description
    db.commit()
    db.refresh(project)
    return project_to_out(project)


@router.delete("/{project_id}", status_code=204)
def delete_project(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = get_project_for_user(db, project_id, current_user)
    require_project_role(db, project_id, current_user, "manager")
    db.delete(project)
    db.commit()


# --- members ---------------------------------------------------------------

@router.get("/{project_id}/members", response_model=list[ProjectMemberOut])
def list_members(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_project_for_user(db, project_id, current_user)
    rows = (
        db.query(ProjectMember)
        .filter_by(project_id=project_id)
        .order_by(ProjectMember.id)
        .all()
    )
    return [project_member_to_out(m) for m in rows]


@router.post("/{project_id}/members", response_model=ProjectMemberOut, status_code=201)
def add_member(
    project_id: int,
    payload: AddMember,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_project_for_user(db, project_id, current_user)
    require_project_role(db, project_id, current_user, "manager")
    user = db.get(User, payload.user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if get_membership(db, project_id, payload.user_id) is not None:
        raise HTTPException(status_code=409, detail="User is already a member")
    membership = ProjectMember(
        project_id=project_id,
        user_id=payload.user_id,
        project_role=payload.project_role,
    )
    db.add(membership)
    db.commit()
    db.refresh(membership)
    return project_member_to_out(membership)


@router.delete("/{project_id}/members/{user_id}", status_code=204)
def remove_member(
    project_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_project_for_user(db, project_id, current_user)
    require_project_role(db, project_id, current_user, "manager")
    membership = get_membership(db, project_id, user_id)
    if membership is None:
        raise HTTPException(status_code=404, detail="Member not found")
    db.delete(membership)
    db.commit()


# --- tasks of a project ----------------------------------------------------

@router.get("/{project_id}/tasks", response_model=list[TaskOut])
def list_project_tasks(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_project_for_user(db, project_id, current_user)
    rows = (
        db.query(Task)
        .filter_by(project_id=project_id)
        .order_by(Task.id)
        .all()
    )
    return [task_to_out(t) for t in rows]
