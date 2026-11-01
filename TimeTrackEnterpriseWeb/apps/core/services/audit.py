"""Audit logging service."""
from __future__ import annotations

from typing import Any

from apps.core.models import AuditLog
from apps.accounts.models import User


def log_action(
    *,
    user: User | None,
    action: str,
    target_table: str = "",
    target_id: str = "",
    ip_address: str | None = None,
    user_agent: str = "",
    detail: dict[str, Any] | None = None,
) -> AuditLog:
    return AuditLog.objects.create(
        user=user,
        action=action,
        target_table=target_table,
        target_id=str(target_id) if target_id else "",
        ip_address=ip_address,
        user_agent=user_agent,
        detail=detail or {},
    )