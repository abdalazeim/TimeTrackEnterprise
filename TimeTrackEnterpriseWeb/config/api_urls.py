"""API URL configuration.

Every API version lives below ``/api/``.  The routes are grouped by app so a
future version can be mounted next to the current one without touching the
call sites:

===============  ==========================  ==============================
Prefix           Module                      Contents
===============  ==========================  ==============================
``/api/mobile/``   ``apps.modules.mobile_api`` Flutter companion and parent portal
``/api/``        ``apps.modules.api_urls``   Functional API (legacy routes)
                                             (attendance, students, slips,
                                             messaging, reports, printing,
                                             scanner bridge, updates...)
``/api/accounts/``  ``apps.accounts.api_urls``  Session identity for clients
``/api/sync/``   ``apps.synchronization.api_urls``  Device pairing, push/pull and
                                             conflict review
``/api/core/``   ``apps.core.api_urls``      Health and native settings
===============  ==========================  ==============================

The migrated functional rules carry no trailing slash (``/api/students``),
exactly like the previous implementation, so existing clients keep working
without redirects.
"""
from __future__ import annotations

from django.urls import include, path

urlpatterns = [
    # Flutter companion (device sessions, offline scans and parent portal).
    path("mobile/", include("apps.modules.mobile_api_urls")),
    # Synchronisation hub (device tokens, idempotent push, conflict review).
    path("sync/", include("apps.synchronization.api_urls")),
    # Account/session endpoints.
    path("accounts/", include("apps.accounts.api_urls")),
    # Core (Django-native) endpoints.
    path("core/", include("apps.core.api_urls")),
    # Functional API.  Kept last so the more specific prefixes above always
    # win.
    path("", include("apps.modules.api_urls")),
]
