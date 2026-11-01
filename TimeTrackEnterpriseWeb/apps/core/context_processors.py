"""Core context processors for templates."""
from __future__ import annotations

from django.conf import settings


def app_globals(request):
    return {
        "APP_VERSION": getattr(settings, "APP_VERSION", "1.1.20"),
        "APP_TITLE": getattr(settings, "APP_TITLE", "نظام متابعة الحضور"),
        "LANGUAGE_CODE": getattr(settings, "LANGUAGE_CODE", "ar"),
        "LANGUAGES": getattr(settings, "LANGUAGES", [("ar", "العربية")]),
        "DEBUG": settings.DEBUG,
    }