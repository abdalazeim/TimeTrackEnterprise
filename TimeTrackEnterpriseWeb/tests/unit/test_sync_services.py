"""Unit tests for the synchronisation service layer (no HTTP)."""
from __future__ import annotations

import uuid

import pytest

from apps.synchronization import services
from apps.synchronization.models import Device, SyncConflict, SyncRecord

pytestmark = pytest.mark.unit


def item(entity="student", key="2099000101", operation="create", base=0, **payload):
    return {
        "client_id": str(uuid.uuid4()),
        "entity": entity,
        "entity_key": key,
        "operation": operation,
        "payload": payload or {"student_nin": key},
        "base_revision": base,
        "updated_at": "2026-10-29T08:00:00Z",
    }


@pytest.fixture()
def device() -> Device:
    return services.register_device("desktop-test", platform="desktop", app_version="1.0")


def test_capabilities_describe_the_protocol():
    payload = services.capabilities()
    assert payload["version"] == services.SYNC_VERSION
    assert "students" in payload["entities"] or "student" in payload["entities"]
    assert "optimistic-locking" in payload["features"]
    assert payload["operations"] == list(services.OPERATIONS)


def test_register_device_validates_name_and_platform():
    with pytest.raises(services.SyncError):
        services.register_device("   ")
    fallback = services.register_device("tablet", platform="solaris")
    assert fallback.platform == "other"
    assert len(fallback.token) >= 32


def test_push_is_idempotent(device):
    change = item(first_name="أمين")
    first = services.push(device, [change])
    assert first["applied"] == 1
    assert first["duplicates"] == 0

    replay = services.push(device, [change])
    assert replay["duplicates"] == 1
    assert replay["applied"] == 0
    assert SyncRecord.objects.count() == 1


def test_create_on_existing_key_is_a_conflict(device):
    services.push(device, [item()])
    result = services.push(device, [item(first_name="مكرر")])
    assert result["conflicts"] == 1
    record = SyncRecord.objects.get(status="conflict")
    assert record.conflict_detail.resolution == "pending"
    assert result["results"][0]["conflict_id"] == str(record.conflict_detail.pk)


def test_stale_base_revision_is_a_conflict(device):
    services.push(device, [item()])
    services.push(device, [item(operation="update", base=1, first_name="أول")])
    stale = services.push(device, [item(operation="update", base=1, first_name="ثانٍ")])
    assert stale["conflicts"] == 1
    assert SyncRecord.objects.filter(status="conflict").count() == 1


def test_invalid_items_are_rejected_without_aborting_the_batch(device):
    result = services.push(
        device,
        [
            {"entity": "planet", "entity_key": "x", "payload": {}},
            {"entity": "student", "entity_key": "", "payload": {}},
            {"entity": "student", "entity_key": "ok", "payload": {}, "client_id": "not-a-uuid"},
            item(key="2099000999"),
        ],
    )
    assert result["rejected"] == 3
    assert result["applied"] == 1


def test_pull_returns_only_other_devices_changes(device):
    peer = services.register_device("phone", platform="android")
    services.push(device, [item(key="mine")])
    services.push(peer, [item(key="theirs")])

    result = services.pull(device)
    assert [change["entity_key"] for change in result["changes"]] == ["theirs"]
    assert result["count"] == 1


def test_pull_filters_by_entity_and_validates_it(device):
    peer = services.register_device("phone", platform="android")
    services.push(peer, [item(entity="student", key="s1")])
    services.push(peer, [item(entity="attendance", key="a1")])

    students = services.pull(device, entity="student")
    assert students["count"] == 1
    assert students["changes"][0]["entity"] == "student"

    with pytest.raises(services.SyncError):
        services.pull(device, entity="unknown")


def test_resolve_conflict_keeps_the_client_copy(device):
    services.push(device, [item()])
    services.push(device, [item(first_name="عميل")])
    conflict = SyncConflict.objects.get(resolution="pending")

    record = services.resolve_conflict(conflict, "local", actor="admin")
    conflict.refresh_from_db()
    assert conflict.resolution == "local"
    assert conflict.resolved_by == "admin"
    assert record.status == "applied"
    assert record.payload["first_name"] == "عميل"
    assert record.server_revision == 3


def test_resolve_conflict_keeps_the_server_copy(device):
    services.push(device, [item(first_name="خادم")])
    services.push(device, [item(first_name="عميل")])
    conflict = SyncConflict.objects.get(resolution="pending")

    record = services.resolve_conflict(conflict, "server", actor="admin")
    assert record.status == "rejected"
    assert conflict.resolution == "server"


def test_resolve_conflict_accepts_a_merged_payload(device):
    services.push(device, [item(first_name="خادم")])
    services.push(device, [item(first_name="عميل")])
    conflict = SyncConflict.objects.get(resolution="pending")

    merged = {"student_nin": "2099000101", "first_name": "مدمج"}
    record = services.resolve_conflict(conflict, "merged", payload=merged, actor="admin")
    assert record.payload == merged
    assert record.status == "applied"


def test_resolve_rejects_unknown_strategy(device):
    services.push(device, [item()])
    services.push(device, [item()])
    conflict = SyncConflict.objects.get(resolution="pending")
    with pytest.raises(services.SyncError):
        services.resolve_conflict(conflict, "roll-a-dice")
