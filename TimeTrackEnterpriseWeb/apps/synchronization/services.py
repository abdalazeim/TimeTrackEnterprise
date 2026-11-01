"""Synchronisation services.

The service layer is deliberately independent from HTTP: the JSON API in
``apps.synchronization.api`` and the management commands/tests call the same
functions.

Design notes
------------
* Pushes are **idempotent**: the client generates a ``client_id`` (UUID) per
  change; replaying the same batch returns the original result instead of
  creating duplicates.
* Conflict detection is **optimistic**: the client sends the
  ``base_revision`` it edited.  If the server already holds a newer applied
  record for the same entity/key, the push is stored as ``conflict`` and a
  :class:`~apps.synchronization.models.SyncConflict` is created for review.
* ``server_revision`` is a per-entity/key monotonic counter, which makes pulls
  deterministic without a global lock.
"""
from __future__ import annotations

import uuid
from typing import Any, Iterable

from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.dateparse import parse_datetime

from apps.synchronization.models import Device, SyncConflict, SyncRecord

SYNC_VERSION = 1

ENTITY_TYPES = (
    "student",
    "period",
    "attendance",
    "entry_slip",
    "exit_slip",
    "settings",
    "message_campaign",
)
OPERATIONS = ("create", "update", "delete")
FEATURES = (
    "idempotent-push",
    "optimistic-locking",
    "conflict-review",
    "incremental-pull",
    "device-tokens",
)


class SyncError(ValueError):
    """Raised for invalid payloads; the API maps it to HTTP 400."""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _as_uuid(value: Any) -> uuid.UUID | None:
    if value in (None, ""):
        return None
    try:
        return uuid.UUID(str(value))
    except (ValueError, AttributeError, TypeError) as exc:
        raise SyncError("client_id غير صالح.") from exc


def _as_revision(value: Any) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError) as exc:
        raise SyncError("base_revision غير صالح.") from exc


def _parse_datetime(value: Any):
    if not value:
        return None
    if hasattr(value, "isoformat") and not isinstance(value, str):
        return value
    parsed = parse_datetime(str(value))
    if parsed is None:
        try:
            from datetime import datetime

            parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except ValueError:
            return None
    if timezone.is_aware(parsed):
        from datetime import timezone as dt_timezone

        parsed = timezone.make_naive(parsed, dt_timezone.utc)
    return parsed


def capabilities() -> dict[str, Any]:
    return {
        "version": SYNC_VERSION,
        "entities": list(ENTITY_TYPES),
        "operations": list(OPERATIONS),
        "features": list(FEATURES),
        "server_time": timezone.now().isoformat(timespec="seconds"),
    }


def authenticate(token: str | None) -> Device | None:
    if not token:
        return None
    return Device.objects.filter(token=token, is_active=True).first()


def register_device(
    name: str, platform: str = "desktop", app_version: str = "", created_by: str = ""
) -> Device:
    name = (name or "").strip()
    if not name:
        raise SyncError("اسم الجهاز مطلوب.")
    if platform not in dict(Device.PLATFORMS):
        platform = "other"
    return Device.objects.create(
        name=name[:120],
        platform=platform,
        app_version=(app_version or "")[:32],
        created_by=(created_by or "")[:64],
    )


def touch(device: Device) -> None:
    Device.objects.filter(pk=device.pk).update(last_seen_at=timezone.now())


# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------
def _latest_record(entity: str, entity_key: str) -> SyncRecord | None:
    return (
        SyncRecord.objects.filter(entity=entity, entity_key=entity_key)
        .exclude(status="rejected")
        .order_by("-server_revision", "-created_at")
        .first()
    )


def _normalise_item(item: dict[str, Any]) -> dict[str, Any]:
    entity = str(item.get("entity") or "").strip()
    if entity not in ENTITY_TYPES:
        raise SyncError(f"الكيان غير مدعوم: {entity or '—'}")
    entity_key = str(item.get("entity_key") or item.get("key") or "").strip()
    if not entity_key:
        raise SyncError("entity_key مطلوب.")
    operation = str(item.get("operation") or "update").lower()
    if operation not in OPERATIONS:
        raise SyncError(f"العملية غير مدعومة: {operation}")
    payload = item.get("payload") or {}
    if not isinstance(payload, dict):
        raise SyncError("payload يجب أن يكون كائن JSON.")
    return {
        "client_id": _as_uuid(item.get("client_id")),
        "entity": entity,
        "entity_key": entity_key[:128],
        "operation": operation,
        "payload": payload,
        "base_revision": _as_revision(item.get("base_revision")),
        "client_updated_at": _parse_datetime(item.get("updated_at")),
    }


def push(device: Device, items: Iterable[dict[str, Any]]) -> dict[str, Any]:
    """Apply a batch of changes from ``device``; safe to retry."""

    items = list(items or [])
    if len(items) > 1000:
        raise SyncError("الدفعة كبيرة جدًا (الحد 1000 عنصر).")

    results: list[dict[str, Any]] = []
    applied = duplicates = conflicts = rejected = 0

    for raw in items:
        try:
            item = _normalise_item(raw)
        except SyncError as exc:
            rejected += 1
            results.append({"status": "rejected", "error": str(exc)})
            continue

        client_id = item["client_id"]
        if client_id:
            existing = SyncRecord.objects.filter(client_id=client_id).first()
            if existing:
                duplicates += 1
                results.append(_record_result(existing, duplicate=True))
                continue

        try:
            with transaction.atomic():
                latest = _latest_record(item["entity"], item["entity_key"])
                latest_revision = latest.server_revision if latest else 0
                next_revision = latest_revision + 1

                conflict = False
                if latest is not None:
                    if item["operation"] == "create":
                        conflict = True
                    elif item["base_revision"] and item["base_revision"] < latest.server_revision:
                        conflict = True

                status = "conflict" if conflict else "applied"
                record = SyncRecord.objects.create(
                    client_id=client_id,
                    device=device,
                    entity=item["entity"],
                    entity_key=item["entity_key"],
                    operation=item["operation"],
                    payload=item["payload"],
                    base_revision=item["base_revision"],
                    server_revision=next_revision,
                    status=status,
                    applied_at=None if conflict else timezone.now(),
                )
                if conflict:
                    SyncConflict.objects.create(
                        record=record,
                        server_payload=(latest.payload if latest else {}),
                        client_payload=item["payload"],
                        resolution="pending",
                    )
                    conflicts += 1
                else:
                    # A superseded pending conflict is no longer actionable.
                    SyncConflict.objects.filter(
                        record__entity=item["entity"],
                        record__entity_key=item["entity_key"],
                        resolution="pending",
                    ).exclude(record=record).update(resolution="server", resolved_at=timezone.now())
                    applied += 1
                results.append(_record_result(record))
        except IntegrityError:
            # Concurrent replay of the same client_id: return the winner.
            existing = SyncRecord.objects.filter(client_id=client_id).first() if client_id else None
            if existing:
                duplicates += 1
                results.append(_record_result(existing, duplicate=True))
            else:
                rejected += 1
                results.append({"status": "rejected", "error": "تعذر حفظ السجل."})

    touch(device)
    return {
        "applied": applied,
        "duplicates": duplicates,
        "conflicts": conflicts,
        "rejected": rejected,
        "results": results,
    }


def _record_result(record: SyncRecord, duplicate: bool = False) -> dict[str, Any]:
    payload = {
        "client_id": str(record.client_id) if record.client_id else None,
        "entity": record.entity,
        "entity_key": record.entity_key,
        "status": record.status,
        "server_revision": record.server_revision,
        "duplicate": duplicate,
    }
    if record.status == "conflict":
        try:
            payload["conflict_id"] = str(record.conflict_detail.pk)
        except SyncConflict.DoesNotExist:  # pragma: no cover - defensive
            payload["conflict_id"] = None
    return payload


# ---------------------------------------------------------------------------
# Pull / conflicts
# ---------------------------------------------------------------------------
def pull(
    device: Device,
    since: str | None = None,
    entity: str | None = None,
    limit: int = 500,
) -> dict[str, Any]:
    # Capture the cursor *before* querying.  A record written while the query
    # runs then has ``created_at >= cursor`` and is returned by the next pull;
    # taking it afterwards could silently skip that record.
    cursor = timezone.now()
    queryset = SyncRecord.objects.select_related("device").filter(status="applied")
    if entity:
        if entity not in ENTITY_TYPES:
            raise SyncError("الكيان غير مدعوم.")
        queryset = queryset.filter(entity=entity)
    if since:
        since_dt = _parse_datetime(since)
        if since_dt is not None:
            queryset = queryset.filter(created_at__gt=since_dt)
    # The client already knows its own changes.
    wanted = max(1, min(limit, 2000))
    records = list(
        queryset.exclude(device=device).order_by("created_at", "id")[:wanted]
    )
    changes = [
        {
            "entity": record.entity,
            "entity_key": record.entity_key,
            "operation": record.operation,
            "payload": record.payload,
            "server_revision": record.server_revision,
            "device": str(record.device_id),
            "updated_at": record.created_at.isoformat(timespec="seconds"),
        }
        for record in records
    ]
    touch(device)
    # When the page is full there may be more rows: resume from the last row we
    # actually returned instead of from ``cursor`` (which would skip the rest).
    # Microseconds keep the contract precise enough for the next ``since``.
    resume = records[-1].created_at if len(records) >= wanted else cursor
    return {
        "changes": changes,
        "count": len(changes),
        "server_time": cursor.isoformat(timespec="microseconds"),
        "next_since": resume.isoformat(timespec="microseconds"),
    }


def pending_conflicts() -> list[SyncConflict]:
    return list(
        SyncConflict.objects.select_related("record", "record__device")
        .filter(resolution="pending")
        .order_by("-created_at")
    )


def resolve_conflict(
    conflict: SyncConflict,
    strategy: str,
    payload: dict[str, Any] | None = None,
    actor: str = "",
) -> SyncRecord:
    if strategy not in {"local", "server", "merged"}:
        raise SyncError("طريقة الحل غير صالحة.")
    if conflict.resolution != "pending":
        return conflict.record

    record = conflict.record
    latest = _latest_record(record.entity, record.entity_key)
    next_revision = (latest.server_revision if latest else record.server_revision) + 1

    with transaction.atomic():
        if strategy == "server":
            record.status = "rejected"
            record.error = "اعتُمدت نسخة الخادم."
            resolved_payload: dict[str, Any] = dict(conflict.server_payload or {})
        elif strategy == "local":
            resolved_payload = dict(conflict.client_payload or {})
            record.payload = resolved_payload
            record.status = "applied"
            record.server_revision = next_revision
            record.applied_at = timezone.now()
        else:
            resolved_payload = dict(payload or {})
            record.payload = resolved_payload
            record.status = "applied"
            record.server_revision = next_revision
            record.applied_at = timezone.now()

        record.save(
            update_fields=["payload", "status", "server_revision", "error", "applied_at"]
        )
        conflict.resolution = strategy
        conflict.resolved_payload = resolved_payload
        conflict.resolved_by = (actor or "")[:64]
        conflict.resolved_at = timezone.now()
        conflict.save(
            update_fields=[
                "resolution",
                "resolved_payload",
                "resolved_by",
                "resolved_at",
            ]
        )
    return record


def serialise_conflict(conflict: SyncConflict) -> dict[str, Any]:
    record = conflict.record
    return {
        "id": str(conflict.pk),
        "resolution": conflict.resolution,
        "entity": record.entity,
        "entity_key": record.entity_key,
        "operation": record.operation,
        "device": str(record.device_id),
        "server_payload": conflict.server_payload,
        "client_payload": conflict.client_payload,
        "resolved_payload": conflict.resolved_payload,
        "resolved_by": conflict.resolved_by,
        "created_at": conflict.created_at.isoformat(timespec="seconds"),
    }
