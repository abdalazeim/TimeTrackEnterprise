"""Test settings: temporary SQLite file, fast auth, no background jobs.

A temporary *file* database is used (instead of ``:memory:``) because the
migrated functional layer keeps its own SQLite connection to ``DB_PATH``;
both Django and the legacy services must see the same data.
"""
from __future__ import annotations

import tempfile
from pathlib import Path

from .base import *  # noqa: F401,F403

DEBUG = False
ALLOWED_HOSTS = ["*"]
TESTING = True
START_BACKGROUND_JOBS = False
DISABLE_SCHEDULER = True
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

_DATA_ROOT = Path(tempfile.mkdtemp(prefix="smart-attendance-test-"))
for _sub in ("photos", "uploads", "tmp", "logs", "updates", "media", "backups"):
    (_DATA_ROOT / _sub).mkdir(parents=True, exist_ok=True)

DATA_DIR = _DATA_ROOT
DB_PATH = _DATA_ROOT / "attendance.db"
PHOTOS_DIR = _DATA_ROOT / "photos"
UPLOADS_DIR = _DATA_ROOT / "uploads"
TMP_DIR = _DATA_ROOT / "tmp"
LOGS_DIR = _DATA_ROOT / "logs"
UPDATES_DIR = _DATA_ROOT / "updates"
BACKUPS_DIR = _DATA_ROOT / "backups"
MEDIA_ROOT = _DATA_ROOT / "media"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": str(DB_PATH),
        "ATOMIC_REQUESTS": False,
        "CONN_MAX_AGE": 0,
        "OPTIONS": {"timeout": 20},
        # Django normally swaps SQLite for ``:memory:`` during tests, which
        # would give the Django ORM and the legacy compatibility layer two
        # different databases.  Pin the test database to the same file.
        "TEST": {"NAME": str(DB_PATH)},
    }
}

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"null": {"class": "logging.NullHandler"}},
    "root": {"handlers": ["null"], "level": "WARNING"},
}
