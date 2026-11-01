"""Development settings: local server, debug console, relaxed hosts."""
from __future__ import annotations

from .base import *  # noqa: F401,F403

DEBUG = True
ALLOWED_HOSTS = ["*"]

# The Django development server reloads itself; the scheduler is started in
# the child process only (see apps.core.apps.CoreConfig.ready).
START_BACKGROUND_JOBS = True
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False
