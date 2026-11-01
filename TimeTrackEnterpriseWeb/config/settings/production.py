"""Production settings: HTTPS, secure cookies, HSTS, restricted hosts."""
from __future__ import annotations

import os

from .base import *  # noqa: F401,F403

DEBUG = False
ALLOWED_HOSTS = [
    host.strip()
    for host in os.environ.get("ATTENDANCE_ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")
    if host.strip()
]

CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("ATTENDANCE_CSRF_TRUSTED_ORIGINS", "").split(",")
    if origin.strip()
]

CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True
SECURE_SSL_REDIRECT = os.environ.get("ATTENDANCE_SSL_REDIRECT", "1") == "1"
SECURE_HSTS_SECONDS = int(os.environ.get("ATTENDANCE_HSTS_SECONDS", "31536000"))
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

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
CSP_UPGRADE_INSECURE_REQUESTS = "1"

START_BACKGROUND_JOBS = os.environ.get("ATTENDANCE_BACKGROUND_JOBS", "1") == "1"
