"""Synchronisation app configuration."""
from __future__ import annotations

from django.apps import AppConfig


class SynchronizationConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.synchronization"
    verbose_name = "المزامنة بين الأجهزة"
