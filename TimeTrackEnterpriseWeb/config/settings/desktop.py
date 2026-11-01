"""Desktop settings: PyInstaller-frozen EXE, portable data folder.

When the application runs from a frozen executable the bundle directory is
``sys._MEIPASS`` (templates/static) while user data must stay next to the
``.exe`` so the whole folder can be copied on a USB stick.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from .base import *  # noqa: F401,F403

DEBUG = False
ALLOWED_HOSTS = ["*"]

FROZEN = bool(getattr(sys, "frozen", False))

if FROZEN:
    BUNDLE_DIR = Path(getattr(sys, "_MEIPASS"))
    EXECUTABLE_DIR = Path(sys.executable).resolve().parent
else:
    BUNDLE_DIR = BASE_DIR
    EXECUTABLE_DIR = BASE_DIR

DATA_DIR = Path(os.environ.get("ATTENDANCE_DATA_DIR") or (EXECUTABLE_DIR / "data")).resolve()
DATA_DIR.mkdir(parents=True, exist_ok=True)
for _sub in ("photos", "uploads", "tmp", "logs", "updates", "media", "backups"):
    (DATA_DIR / _sub).mkdir(parents=True, exist_ok=True)

DB_PATH = DATA_DIR / "attendance.db"
PHOTOS_DIR = DATA_DIR / "photos"
UPLOADS_DIR = DATA_DIR / "uploads"
TMP_DIR = DATA_DIR / "tmp"
LOGS_DIR = DATA_DIR / "logs"
UPDATES_DIR = DATA_DIR / "updates"
BACKUPS_DIR = DATA_DIR / "backups"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": str(DB_PATH),
        "ATOMIC_REQUESTS": False,
        "CONN_MAX_AGE": 0,
        "OPTIONS": {"timeout": 20},
    }
}

MEDIA_ROOT = DATA_DIR / "media"
STATIC_ROOT = BUNDLE_DIR / "staticfiles"
STATICFILES_DIRS = [BUNDLE_DIR / "static"]

# Templates ship inside the bundle.
TEMPLATES[0]["DIRS"] = []  # noqa: F405 - DjangoTemplates (admin only)
TEMPLATES[1]["DIRS"] = [BUNDLE_DIR / "templates"]  # noqa: F405 - Jinja2

# The frozen desktop build serves plain HTTP on a loopback/LAN address.
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
SECURE_SSL_REDIRECT = False

START_BACKGROUND_JOBS = os.environ.get("ATTENDANCE_BACKGROUND_JOBS", "1") == "1"

# Only the workstation's own addresses are accepted, and ``/admin/`` is
# restricted to loopback (see config/desktop_security.py).
from config.desktop_security import DesktopAdminLoopbackMiddleware, apply  # noqa: E402

apply(globals())
MIDDLEWARE = [  # noqa: F405
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "apps.core.middleware.compat.CompatRequestMiddleware",
    "apps.core.middleware.rate_limit.RateLimitMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "apps.accounts.middleware.AccountGateMiddleware",
    "config.desktop_security.DesktopAdminLoopbackMiddleware",
]
