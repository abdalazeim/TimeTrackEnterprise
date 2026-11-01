"""Core (Django-native) API patterns, mounted under ``/api/core/``.

The functional settings API (``/api/settings``) belongs to
:mod:`apps.modules.api`; this module only exposes infrastructure probes.
"""
from __future__ import annotations

from django.urls import path

from apps.core import views

urlpatterns = [
    path("health/", views.health, name="api_core_health"),
]
