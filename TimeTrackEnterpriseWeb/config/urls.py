"""Top-level URL configuration for TimeTrack Enterprise.

Route order matters:

1. ``/admin/`` — Django administration (Jinja templates never see it).
2. ``/api/`` — JSON API, see :mod:`config.api_urls`.
3. ``/i18n/`` — language switch helper for native Django views.
4. ``/`` — the migrated page routes (``/login``, ``/students`` ...).
5. ``/`` — the core app (``/health/``, ``/core/...``).
"""
from __future__ import annotations

from django.conf import settings
from django.contrib import admin
from django.urls import include, path, re_path
from django.views.i18n import set_language

from apps.core import views as core_views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("i18n/set-language/", set_language, name="set_language"),
    # ``waitress`` (desktop) and gunicorn do not serve static files themselves;
    # this keeps the application usable without nginx or ``runserver``.
    re_path(
        rf"^{settings.STATIC_URL.lstrip('/')}(?P<path>.*)$",
        core_views.static_file,
        name="static_serve",
    ),
    path("api/", include("config.api_urls")),
    # Login/logout and the rest of the migrated page routes share the root
    # prefix because the legacy application did the same.
    path("", include("apps.accounts.urls")),
    path("", include("apps.modules.urls")),
    path("", include("apps.core.urls")),
]

# Error handlers rendering the localised Jinja pages (see apps/core/errors.py).
handler400 = "apps.core.errors.handler400"
handler403 = "apps.core.errors.handler403"
handler404 = "apps.core.errors.handler404"
handler500 = "apps.core.errors.handler500"
