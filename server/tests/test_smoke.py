"""Example API tests for the TaskFlow playground.

These illustrate the patterns QA learners should practice: auth, CRUD,
filtering/search/pagination, RBAC (403), audit log and test-scenario injection.
Run with:  cd server && pytest -q
"""
from __future__ import annotations


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# --- auth -------------------------------------------------------------------

def test_login_success(client, admin_token):
    assert admin_token


def test_login_wrong_password(client):
    r = client.post(
        "/api/auth/login",
        json={"email": "admin@test.local", "password": "nope"},
    )
    assert r.status_code == 401


def test_invalid_token_rejected(client):
    r = client.get("/api/tasks", headers=auth("not-a-real-token"))
    assert r.status_code == 401


def test_me(client, admin_token):
    r = client.get("/api/auth/me", headers=auth(admin_token))
    assert r.status_code == 200
    assert r.json()["email"] == "admin@test.local"
    assert r.json()["role"] == "admin"


def test_register_then_login_and_me(client):
    r = client.post(
        "/api/auth/register",
        json={"email": "qa-newbie@test.local", "password": "secret1", "full_name": "QA Newbie"},
    )
    assert r.status_code == 201
    # Every registered user starts with the `member` role.
    assert r.json()["role"] == "member"

    login = client.post(
        "/api/auth/login",
        json={"email": "qa-newbie@test.local", "password": "secret1"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]

    me = client.get("/api/auth/me", headers=auth(token))
    assert me.status_code == 200
    assert me.json()["email"] == "qa-newbie@test.local"
    assert me.json()["full_name"] == "QA Newbie"


def test_register_duplicate_email_conflict(client):
    # admin@test.local exists in the seed; re-registering it must fail.
    r = client.post(
        "/api/auth/register",
        json={"email": "admin@test.local", "password": "whatever1"},
    )
    assert r.status_code == 409


# --- tasks: list / filter / search / pagination -----------------------------

def test_list_tasks_pagination(client, admin_token):
    r = client.get("/api/tasks?page=1&page_size=5", headers=auth(admin_token))
    assert r.status_code == 200
    body = r.json()
    assert len(body["items"]) <= 5
    assert body["page"] == 1
    assert body["page_size"] == 5
    assert body["total"] >= 5


def test_filter_tasks_by_status(client, admin_token):
    r = client.get("/api/tasks?status=todo", headers=auth(admin_token))
    assert r.status_code == 200
    assert all(t["status"] == "todo" for t in r.json()["items"])


def test_filter_tasks_by_priority(client, admin_token):
    r = client.get("/api/tasks?priority=urgent", headers=auth(admin_token))
    assert r.status_code == 200
    items = r.json()["items"]
    assert items  # the seed contains urgent tasks
    assert all(t["priority"] == "urgent" for t in items)


def test_search_tasks(client, admin_token):
    r = client.get("/api/tasks?q=login", headers=auth(admin_token))
    assert r.status_code == 200
    assert any("login" in t["title"].lower() for t in r.json()["items"])


# --- CRUD: create / update / delete / comments ------------------------------

def test_create_update_delete_task(client, admin_token):
    # create a project + task
    p = client.post("/api/projects", json={"name": "Temp", "description": "x"}, headers=auth(admin_token))
    assert p.status_code == 201
    pid = p.json()["id"]

    t = client.post(
        f"/api/projects/{pid}/tasks",
        json={"title": "Write tests", "description": "cover the API", "tags": ["automation"]},
        headers=auth(admin_token),
    )
    assert t.status_code == 201
    tid = t.json()["id"]
    assert t.json()["tags"] == ["automation"]

    u = client.patch(
        f"/api/tasks/{tid}",
        json={"status": "in_progress", "priority": "high"},
        headers=auth(admin_token),
    )
    assert u.status_code == 200
    assert u.json()["status"] == "in_progress"
    assert u.json()["priority"] == "high"

    c = client.post(f"/api/tasks/{tid}/comments", json={"body": "nice"}, headers=auth(admin_token))
    assert c.status_code == 201
    comments = client.get(f"/api/tasks/{tid}/comments", headers=auth(admin_token)).json()
    assert len(comments) == 1

    d = client.delete(f"/api/tasks/{tid}", headers=auth(admin_token))
    assert d.status_code == 204
    assert client.get(f"/api/tasks/{tid}", headers=auth(admin_token)).status_code == 404


def test_invalid_status_rejected(client, admin_token):
    p = client.post("/api/projects", json={"name": "P", "description": ""}, headers=auth(admin_token))
    pid = p.json()["id"]
    r = client.post(
        f"/api/projects/{pid}/tasks",
        json={"title": "x", "status": "bogus"},
        headers=auth(admin_token),
    )
    assert r.status_code == 422


# --- RBAC --------------------------------------------------------------------

def test_readonly_cannot_delete(client, readonly_token, admin_token):
    # pick any existing task
    tid = client.get("/api/tasks", headers=auth(admin_token)).json()["items"][0]["id"]
    r = client.delete(f"/api/tasks/{tid}", headers=auth(readonly_token))
    # readonly is a viewer; even if it could see the task, deletion is forbidden.
    assert r.status_code in (403,)


def test_member_blocked_from_foreign_project(client, member_token):
    # member is not in p2 ("Backend Refactor"); listing its tasks via project_id -> 403
    projects = client.get("/api/projects", headers=auth(member_token)).json()
    foreign = [p for p in projects if p["name"] == "Backend Refactor"]
    assert foreign == []  # member does not even see it
    # direct attempt to filter by an id the member can't see
    r = client.get("/api/tasks?project_id=999999", headers=auth(member_token))
    assert r.status_code == 403


# --- notifications ------------------------------------------------------------

def test_member_notification_mark_read(client, member_token):
    # The seed gives `member` one unread notification.
    r = client.get("/api/notifications?unread_only=true", headers=auth(member_token))
    assert r.status_code == 200
    unread = r.json()
    assert len(unread) >= 1
    nid = unread[0]["id"]

    # Mark it as read -> it disappears from the unread list.
    m = client.patch(f"/api/notifications/{nid}", json={"read": True}, headers=auth(member_token))
    assert m.status_code == 200
    assert m.json()["read"] is True

    r2 = client.get("/api/notifications?unread_only=true", headers=auth(member_token))
    assert all(n["id"] != nid for n in r2.json())


def test_cannot_touch_foreign_notification(client, member_token, admin_token):
    # A notification id that does not belong to the caller -> 404, not a leak.
    r = client.patch("/api/notifications/1", json={"read": True}, headers=auth(admin_token))
    assert r.status_code == 404


# --- tags ---------------------------------------------------------------------

def test_create_and_list_tag(client, admin_token):
    r = client.post("/api/tags", json={"name": "regression", "color": "#ff9f0a"},
                    headers=auth(admin_token))
    assert r.status_code == 201
    assert r.json()["name"] == "regression"

    tags = client.get("/api/tags", headers=auth(admin_token)).json()
    names = [t["name"] for t in tags]
    # New tag is listed alongside the seeded ones.
    assert "regression" in names
    assert "ios" in names  # from the seed


def test_create_duplicate_tag_conflict(client, admin_token):
    # "ios" exists in the seed; creating it again must fail with 409.
    r = client.post("/api/tags", json={"name": "ios"}, headers=auth(admin_token))
    assert r.status_code == 409


# --- test controls ----------------------------------------------------------

def test_network_mode_error500(client, admin_token):
    client.post("/api/test-controls/network-mode", json={"mode": "error500"})
    r = client.get("/api/tasks", headers=auth(admin_token))
    assert r.status_code == 500
    client.post("/api/test-controls/network-mode/reset")
    r2 = client.get("/api/tasks", headers=auth(admin_token))
    assert r2.status_code == 200


def test_x_test_scenario_header(client, admin_token):
    r = client.get("/api/tasks", headers={**auth(admin_token), "X-Test-Scenario": "conflict"})
    assert r.status_code == 409


# --- audit ------------------------------------------------------------------

def test_audit_log_records_updates(client, admin_token):
    p = client.post("/api/projects", json={"name": "AuditP", "description": ""}, headers=auth(admin_token))
    pid = p.json()["id"]
    t = client.post(f"/api/projects/{pid}/tasks", json={"title": "to be updated"}, headers=auth(admin_token))
    tid = t.json()["id"]
    client.patch(f"/api/tasks/{tid}", json={"title": "updated title"}, headers=auth(admin_token))
    r = client.get(f"/api/audit?entity_type=task&entity_id={tid}", headers=auth(admin_token))
    assert r.status_code == 200
    actions = [a["action"] for a in r.json()]
    assert "create" in actions
    assert "update" in actions
