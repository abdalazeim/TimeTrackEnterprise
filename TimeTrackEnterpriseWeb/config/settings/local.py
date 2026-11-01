"""Local settings: a developer machine with a custom data folder.

Copy this file to ``config/settings/local_settings.py`` (ignored by git) if
you need personal overrides; everything here can be driven by environment
variables as well.
"""
from __future__ import annotations

import os

from .development import *  # noqa: F401,F403

DEBUG = os.environ.get("ATTENDANCE_DEBUG", "1") == "1"
ALLOWED_HOSTS = ["*"]

# Optional: point the whole runtime data folder somewhere else.
if os.environ.get("ATTENDANCE_DATA_DIR"):
    DATA_DIR = __import__("pathlib").Path(os.environ["ATTENDANCE_DATA_DIR"]).resolve()
    DB_PATH = DATA_DIR / "attendance.db"
    PHOTOS_DIR = DATA_DIR / "photos"
    UPLOADS_DIR = DATA_DIR / "uploads"
    TMP_DIR = DATA_DIR / "tmp"
    LOGS_DIR = DATA_DIR / "logs"
    UPDATES_DIR = DATA_DIR / "updates"
    BACKUPS_DIR = DATA_DIR / "backups"
    MEDIA_ROOT = DATA_DIR / "media"
    DATABASES["default"]["NAME"] = str(DB_PATH)  # noqa: F405

START_BACKGROUND_JOBS = os.environ.get("ATTENDANCE_BACKGROUND_JOBS", "0") == "1"
