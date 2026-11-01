"""PostgreSQL settings (structural / future use).

The migrated functional layer (attendance, slips, messaging, reports,
printing, updates and the scanner bridge) keeps its hand-written SQLite SQL
and therefore requires the SQLite backend.  This module exists so the
enterprise structure can be validated against PostgreSQL and so the
synchronisation app (which uses the Django ORM only) can be migrated there
without code changes.

Enable it with::

    DJANGO_SETTINGS_MODULE=config.settings.test_postgres

and provide the connection through environment variables.  ``DB_PATH`` is
kept pointing at a local SQLite file because the legacy services cannot talk
to PostgreSQL yet; see ``docs/reviews`` for the tracked follow-up work.
"""
from __future__ import annotations

import os
from pathlib import Path

from .test import *  # noqa: F401,F403

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "timetrack"),
        "USER": os.environ.get("POSTGRES_USER", "timetrack"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", ""),
        "HOST": os.environ.get("POSTGRES_HOST", "127.0.0.1"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "ATOMIC_REQUESTS": False,
        "CONN_MAX_AGE": 0,
        "OPTIONS": {},
    }
}

# The legacy compatibility layer still reads/writes a SQLite file.
DB_PATH = Path(
    os.environ.get("ATTENDANCE_DB_PATH")
    or (BASE_DIR / "data" / "TimeTrackEnterprise.db")
)

# Postgres is only used for structural verification in CI.
TESTING = True
START_BACKGROUND_JOBS = False
DISABLE_SCHEDULER = True
