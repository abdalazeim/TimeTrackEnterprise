"""Core URL patterns.

Mounted at the root in :mod:`config.urls`, so ``/health/`` stays available
without authentication (the desktop launcher polls it before showing the
window).
"""
from __future__ import annotations

from django.urls import path

from apps.core import views

urlpatterns = [
    path("health/", views.health, name="core_health"),
    # Legacy alias: the dashboard itself is ``/`` (see apps.modules.views).
    path("dashboard/", views.dashboard, name="core_dashboard"),
    path("backup/download/", views.backup_download, name="core_backup_download"),
]
