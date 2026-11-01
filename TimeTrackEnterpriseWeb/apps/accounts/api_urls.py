"""Account API patterns mounted under ``/api/accounts/``.

User management itself stays in the migrated functional API
(``apps.modules.api`` → ``/api/users``); this module only exposes the
session identity for clients that need it.
"""
from __future__ import annotations

from django.urls import path

from apps.accounts import views

urlpatterns = [
    path("me/", views.session_me, name="accounts_session_me"),
]
