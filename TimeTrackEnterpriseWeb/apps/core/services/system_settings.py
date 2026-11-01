"""System settings service."""
from __future__ import annotations

from typing import Any

from apps.core.models import SystemSetting


def get_setting(key: str, default: str = "") -> str:
    try:
        setting = SystemSetting.objects.get(key=key)
        return setting.value
    except SystemSetting.DoesNotExist:
        return default


def set_setting(key: str, value: str) -> None:
    SystemSetting.objects.update_or_create(key=key, defaults={"value": value})


def get_settings() -> dict[str, str]:
    return {s.key: s.value for s in SystemSetting.objects.all()}