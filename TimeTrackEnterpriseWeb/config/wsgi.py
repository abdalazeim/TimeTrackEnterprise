"""WSGI entry point.

Used by ``waitress`` (desktop/Windows), ``gunicorn`` (Linux servers) and any
other WSGI container::

    waitress-serve --listen=127.0.0.1:8000 config.wsgi:application
"""
from __future__ import annotations

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

application = get_wsgi_application()
