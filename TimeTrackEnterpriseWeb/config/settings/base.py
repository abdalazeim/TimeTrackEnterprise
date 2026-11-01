"""Base Django settings shared by every environment.

Runtime data (SQLite database, photos, uploads, logs, updates) lives in
``DATA_DIR`` next to the project by default so the desktop build stays
portable.  Every path can be overridden with ``ATTENDANCE_DATA_DIR``.
"""
from __future__ import annotations

import os
import secrets
from pathlib import Path

from apps.core import config as legacy_config
from apps.core.database_file import default_database_path

BASE_DIR = Path(__file__).resolve().parent.parent.parent

# ---------------------------------------------------------------------------
# Runtime data layout
# ---------------------------------------------------------------------------
DATA_DIR = Path(os.environ.get("ATTENDANCE_DATA_DIR") or (BASE_DIR / "data")).resolve()
DATA_DIR.mkdir(parents=True, exist_ok=True)
for _sub in ("photos", "uploads", "tmp", "logs", "updates", "media", "backups"):
    (DATA_DIR / _sub).mkdir(parents=True, exist_ok=True)

DB_PATH = default_database_path(DATA_DIR, os.environ.get("ATTENDANCE_DB_PATH"))
PHOTOS_DIR = DATA_DIR / "photos"
UPLOADS_DIR = DATA_DIR / "uploads"
TMP_DIR = DATA_DIR / "tmp"
LOGS_DIR = DATA_DIR / "logs"
UPDATES_DIR = DATA_DIR / "updates"
BACKUPS_DIR = DATA_DIR / "backups"


def _secret_key() -> str:
    configured = os.environ.get("ATTENDANCE_SECRET_KEY") or os.environ.get("ATTENDANCE_SECRET")
    if configured:
        return configured
    key_file = DATA_DIR / ".secret_key"
    try:
        existing = key_file.read_text(encoding="utf-8").strip()
        if existing:
            return existing
        generated = secrets.token_urlsafe(48)
        key_file.write_text(generated, encoding="utf-8")
        return generated
    except OSError:  # read-only directory
        return secrets.token_urlsafe(48)


SECRET_KEY = _secret_key()

DEBUG = False
ALLOWED_HOSTS: list[str] = ["*"]

# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "apps.core",
    "apps.accounts",
    "apps.synchronization",
    "apps.modules",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    # Sets up the Flask-compatible context (request/g/session/current_app),
    # localises responses, adds the legacy security headers and closes the
    # per-thread SQLite connection.
    "apps.core.middleware.compat.CompatRequestMiddleware",
    # Coarse per-IP guard for the login form (see apps/core/middleware/rate_limit.py).
    "apps.core.middleware.rate_limit.RateLimitMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # Login gate, admin gate and API request-header guard.
    "apps.accounts.middleware.AccountGateMiddleware",
]

ROOT_URLCONF = "config.urls"
API_URLS_MODULE = "config.api_urls"

TEMPLATES = [
    # Django templates are required by ``django.contrib.admin`` (and by any
    # future native Django view).  They are listed *first* so admin templates
    # are never parsed by Jinja2.
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
    # All application templates (legacy Flask names) are rendered through the
    # Jinja2 backend and the ``LayoutLoader`` in ``config/jinja2.py``.
    {
        "BACKEND": "django.template.backends.jinja2.Jinja2",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": False,
        "OPTIONS": {
            "environment": "config.jinja2.environment",
            "context_processors": [
                "apps.core.context_processors.app_globals",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": str(DB_PATH),
        "ATOMIC_REQUESTS": False,
        "CONN_MAX_AGE": 0,
        "OPTIONS": {"timeout": 20},
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "accounts.User"
AUTHENTICATION_BACKENDS = ["apps.accounts.backends.LegacyBackend"]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 6}},
]

# ---------------------------------------------------------------------------
# Internationalisation
# ---------------------------------------------------------------------------
LANGUAGE_CODE = "ar"
LANGUAGES = [
    ("ar", "العربية"),
    ("en", "English"),
    ("fr", "Français"),
]
LOCALE_PATHS: list[Path] = []
USE_I18N = True
USE_TZ = False
TIME_ZONE = "Africa/Algiers"

# ---------------------------------------------------------------------------
# Static and media files
# ---------------------------------------------------------------------------
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]
MEDIA_URL = "/media/"
MEDIA_ROOT = DATA_DIR / "media"

# ---------------------------------------------------------------------------
# Sessions and security
# ---------------------------------------------------------------------------
SESSION_ENGINE = "django.contrib.sessions.backends.db"
SESSION_COOKIE_NAME = "attendance_session"
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_AGE = 12 * 60 * 60
SESSION_EXPIRE_AT_BROWSER_CLOSE = False

CSRF_COOKIE_HTTPONLY = True
CSRF_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SECURE = False
CSRF_TRUSTED_ORIGINS: list[str] = []

X_FRAME_OPTIONS = "DENY"
SECURE_REFERRER_POLICY = "same-origin"
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_SSL_REDIRECT = False

CSP_DEFAULT_SRC = ("'self'",)
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'")
CSP_IMG_SRC = ("'self'", "data:", "blob:")
CSP_MEDIA_SRC = ("'self'", "blob:")
CSP_SCRIPT_SRC = ("'self'",)
CSP_CONNECT_SRC = ("'self'",)
CSP_FONT_SRC = ("'self'",)
CSP_OBJECT_SRC = ("none",)
CSP_FRAME_ANCESTORS = ("'none'",)
CSP_BASE_URI = ("'self'",)

# Legacy upload limit (30 MiB) and JSON behaviour.
DATA_UPLOAD_MAX_MEMORY_SIZE = 30 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 30 * 1024 * 1024
DATA_UPLOAD_MAX_NUMBER_FIELDS = 5000
MAX_CONTENT_LENGTH = 30 * 1024 * 1024

# ---------------------------------------------------------------------------
# Application metadata and background workers
# ---------------------------------------------------------------------------
APP_VERSION = legacy_config.APP_VERSION
APP_TITLE = legacy_config.APP_TITLE
APP_SUBTITLE = legacy_config.APP_SUBTITLE
APP_AUTHOR = legacy_config.APP_AUTHOR
APP_LOCATION = legacy_config.APP_LOCATION
APP_REPO_URL = legacy_config.APP_REPO_URL
UPDATE_FEED_URL = legacy_config.UPDATE_FEED_URL
UPDATE_PUBLIC_KEY = legacy_config.UPDATE_PUBLIC_KEY
UPDATE_CHECK_INTERVAL = legacy_config.UPDATE_CHECK_INTERVAL

SCHEDULER_INTERVAL = int(os.environ.get("ATTENDANCE_SCHEDULER_INTERVAL", "25"))
DISABLE_SCHEDULER = os.environ.get("ATTENDANCE_DISABLE_SCHEDULER", "0") == "1"
START_BACKGROUND_JOBS = True
TESTING = False

# Legacy console/desktop launchers rely on these endpoints.
LOGIN_URL = "/login"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/login"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {"format": "%(asctime)s %(levelname)s [%(name)s] %(message)s"},
        "verbose": {"format": "%(asctime)s %(levelname)s [%(name)s] %(message)s"},
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "default"},
        "file": {
            "class": "logging.handlers.RotatingFileHandler",
            "filename": str(LOGS_DIR / "app.log"),
            "maxBytes": 2 * 1024 * 1024,
            "backupCount": 3,
            "encoding": "utf-8",
            "formatter": "default",
        },
    },
    "loggers": {
        "attendance": {"handlers": ["console", "file"], "level": "INFO", "propagate": False},
        "django.request": {"handlers": ["console", "file"], "level": "ERROR", "propagate": False},
    },
    "root": {"handlers": ["console"], "level": "INFO"},
}
