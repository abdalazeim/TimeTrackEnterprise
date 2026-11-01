"""Core views: health probe, legacy dashboard alias and database backup.

These are thin Django-native endpoints.  Everything account-related (login,
logout, session) lives in :mod:`apps.accounts` and the functional pages are
served by the migrated Flask-style blueprint in :mod:`apps.modules.views`.
"""
from __future__ import annotations

from pathlib import Path

from django.conf import settings
from django.http import Http404, HttpResponse, JsonResponse
from django.shortcuts import redirect
from django.views.decorators.http import require_GET

from apps.core.compat import g
from apps.core.errors import error_response


def _admin_denied(request):
    """Return an error response unless the session user is an administrator."""
    user = g.get("user")
    if not user:
        return error_response(request, 401)
    if user.get("role") != "admin":
        return error_response(request, 403)
    return None


@require_GET
def health(request):
    """Liveness probe used by the desktop launcher and the reverse proxy."""
    return JsonResponse(
        {
            "ok": True,
            "app": "StudentAttendance",
            "version": getattr(settings, "APP_VERSION", ""),
        }
    )


@require_GET
def dashboard(request):
    """Backwards-compatible ``/core/dashboard/`` alias.

    The real dashboard is the migrated functional page at ``/``; keeping the
    redirect means old bookmarks and the Django admin shortcut still work.
    """
    return redirect("/")


@require_GET
def backup_download(request):
    """Download a gzip copy of the SQLite database (administrators only)."""
    denied = _admin_denied(request)
    if denied is not None:
        return denied

    from apps.core.services.backup import create_backup

    backup_dir = Path(settings.DATA_DIR) / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup_path = backup_dir / "attendance_backup.gz"
    create_backup(backup_path)
    response = HttpResponse(backup_path.read_bytes(), content_type="application/gzip")
    response["Content-Disposition"] = 'attachment; filename="attendance_backup.gz"'
    return response


@require_GET
def static_file(request, path: str):
    """Serve ``/static/...`` in production and in the frozen desktop build.

    ``django.contrib.staticfiles`` only serves files from ``runserver``; the
    desktop launcher uses waitress, and the container image serves the app
    behind nginx.  This view keeps the application self-contained (the bundle
    ships ``static/``) while delegating path resolution and traversal
    protection to the staticfiles finders.
    """
    from django.contrib.staticfiles import finders

    from apps.core.compat import send_file

    absolute = finders.find(path)
    if not absolute:
        raise Http404("Static file not found")
    return send_file(absolute, max_age=86400 if settings.DEBUG else 604800)
