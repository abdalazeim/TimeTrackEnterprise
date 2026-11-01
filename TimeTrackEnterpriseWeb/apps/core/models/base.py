"""Foundation models shared across the project."""
from __future__ import annotations

from datetime import datetime

from django.db import models


class BaseModel(models.Model):
    """Abstract base adding created/updated timestamps to every model."""

    created_at = models.DateTimeField(default=datetime.now, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.__class__.__name__} #{self.pk}"


class AuditLog(BaseModel):
    """Append-only record of privileged or data-changing actions."""

    ACTION_CHOICES = (
        ("create", "create"),
        ("update", "update"),
        ("delete", "delete"),
        ("login", "login"),
        ("logout", "logout"),
        ("backup", "backup"),
        ("shutdown", "shutdown"),
        ("import", "import"),
        ("close_period", "close_period"),
        ("excuse", "excuse"),
        ("issue_slip", "issue_slip"),
        ("send_sms", "send_sms"),
        ("update_check", "update_check"),
        ("update_install", "update_install"),
    )

    user = models.ForeignKey(
        "accounts.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    action = models.CharField(max_length=32, choices=ACTION_CHOICES, db_index=True)
    target_table = models.CharField(max_length=64, blank=True, db_index=True)
    target_id = models.CharField(max_length=64, blank=True, db_index=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, blank=True)
    detail = models.JSONField(default=dict, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["action", "created_at"]),
            models.Index(fields=["target_table", "target_id"]),
        ]


class SystemSetting(BaseModel):
    """Single-row-per-key configuration table.

    The legacy app stored settings in a free-form ``settings`` table; this model
    keeps the same key/value semantics but exposes them through Django ORM.
    """

    key = models.CharField(max_length=64, unique=True, db_index=True)
    value = models.TextField(default="")

    class Meta:
        ordering = ["key"]

    def __str__(self) -> str:  # pragma: no cover - trivial
        return self.key


class LookupCategory(BaseModel):
    """Reusable enumeration-like catalog (e.g. entry-slip reasons)."""

    name = models.CharField(max_length=80, unique=True)
    items = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ["name"]