"""Functional modules app (attendance, slips, messaging, reports...)."""
from __future__ import annotations

from django.apps import AppConfig


class ModulesConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.modules"
    verbose_name = "الوحدات الوظيفية"
