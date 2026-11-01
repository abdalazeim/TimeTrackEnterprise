"""pytest configuration for the Django application.

The functional layer keeps its own SQLite connection (``apps.core.db``) while
Django owns sessions, auth and the sync tables.  Both point at the same test
file, so the fixtures below:

* use ``transactional_db`` (real commits, no wrapping transaction) so the two
  connections see the same data;
* recreate the legacy tables before every test, which isolates hand-written
  SQL from the previous test and restores the seeded administrator/periods;
* expose a Flask-like client (see ``tests/support.py``) so the migrated tests
  keep their original, readable assertions.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests.support import CompatClient, CompatTestApp  # noqa: E402

# Tables created by ``apps.core.db.SCHEMA`` (no Django models).
LEGACY_TABLES = (
    "message_outbox",
    "message_campaigns",
    "exit_slips",
    "entry_slips",
    "period_closures",
    "sms_logs",
    "attendance_logs",
    "periods",
    "students",
    "users",
    "settings",
    "app_meta",
)


@pytest.fixture(autouse=True)
def legacy_schema(transactional_db):
    """Recreate the legacy schema and seed the default data for each test."""
    from apps.core.compat import get_app
    from apps.core.db import close_db, ensure_database, get_db
    from apps.modules.services.messaging_service import MessageJobManager
    from apps.modules.services.sms_service import SmsJobManager

    close_db()
    connection = get_db()
    try:
        connection.execute("PRAGMA foreign_keys = OFF")
        for table in LEGACY_TABLES:
            connection.execute(f'DROP TABLE IF EXISTS "{table}"')
        connection.commit()
        connection.execute("PRAGMA foreign_keys = ON")
    finally:
        close_db()

    ensure_database()

    app = get_app()
    app.refresh()
    app.extensions["sms_jobs"] = SmsJobManager()
    app.extensions["message_jobs"] = MessageJobManager()

    yield

    close_db()


@pytest.fixture()
def app(legacy_schema) -> CompatTestApp:
    return CompatTestApp()


@pytest.fixture()
def client(legacy_schema) -> CompatClient:
    from apps.core.db import get_db

    compat = CompatClient()
    row = get_db().execute(
        "SELECT id FROM users WHERE username = 'admin' LIMIT 1"
    ).fetchone()
    with compat.session_transaction() as session:
        session["user_id"] = row[0] if row else 1
        session["csrf_token"] = "test-csrf"
    return compat


@pytest.fixture()
def anon(app) -> CompatClient:
    return CompatClient()


@pytest.fixture()
def csrf() -> dict[str, str]:
    return {"X-Requested-With": "StudentAttendance"}


@pytest.fixture()
def db(legacy_schema):
    """Dedicated SQLite connection for assertions written in raw SQL.

    Requests close the per-thread compatibility connection at the end of each
    response, so the tests get their own connection instead of the shared one.
    """
    from django.conf import settings

    from apps.core.db import connect

    connection = connect(settings.DB_PATH)
    try:
        yield connection
    finally:
        connection.close()


@pytest.fixture()
def make_student(client, csrf):
    counter = {"value": 0}

    def _make(**overrides):
        counter["value"] += 1
        payload = {
            "student_nin": f"109900{counter['value']:04d}",
            "first_name": "أمين",
            "last_name": "بن علي",
            "birth_date": "2010-05-12",
            "class_group": "1AS1",
            "parent_phone": "0550123456",
        }
        payload.update(overrides)
        response = client.post("/api/students", json=payload, headers=csrf)
        assert response.status_code == 200, response.get_json()
        return response.get_json()["student"]

    return _make


@pytest.fixture()
def period(client):
    response = client.get("/api/periods")
    assert response.status_code == 200
    periods = response.get_json()["periods"]
    assert periods
    return periods[0]
