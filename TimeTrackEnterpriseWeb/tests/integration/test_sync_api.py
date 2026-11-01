"""Integration tests for the ``/api/sync/`` endpoints."""
from __future__ import annotations

import uuid

import pytest

pytestmark = pytest.mark.integration

CSRF = {"X-Requested-With": "StudentAttendance"}


def register(client, name="desktop"):
    response = client.post(
        "/api/sync/devices/", json={"name": name, "platform": "desktop"}, headers=CSRF
    )
    assert response.status_code == 201, response.get_json()
    return response.get_json()["device"]


def change(entity="student", key="2099000101", operation="create", base=0):
    return {
        "client_id": str(uuid.uuid4()),
        "entity": entity,
        "entity_key": key,
        "operation": operation,
        "base_revision": base,
        "payload": {"student_nin": key, "first_name": "أمين"},
        "updated_at": "2026-10-29T08:00:00Z",
    }


def test_capabilities_are_public(anon):
    response = anon.get("/api/sync/capabilities/")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload["ok"] is True
    assert payload["version"] == 1
    assert "optimistic-locking" in payload["features"]


def test_device_registration_requires_a_session(anon):
    assert anon.get("/api/sync/devices/").status_code == 401
    assert anon.post("/api/sync/devices/", json={"name": "x"}).status_code == 401


def test_admin_registers_lists_and_deactivates_devices(client, anon):
    device = register(client)
    assert device["token"]

    listing = client.get("/api/sync/devices/").get_json()
    assert [item["name"] for item in listing["devices"]] == ["desktop"]

    response = client.post(
        f"/api/sync/devices/{device['id']}/deactivate/", headers=CSRF
    )
    assert response.status_code == 200

    push = anon.post(
        "/api/sync/push/",
        json={"changes": [change()]},
        headers={"X-Device-Token": device["token"]},
    )
    assert push.status_code == 401


def test_idempotent_push_and_incremental_pull(client, anon):
    device = register(client)
    peer = register(client, "phone")
    headers = {"X-Device-Token": device["token"]}
    peer_headers = {"X-Device-Token": peer["token"]}

    item = change()
    first = anon.post("/api/sync/push/", json={"changes": [item]}, headers=headers)
    assert first.status_code == 200, first.get_json()
    assert first.get_json()["applied"] == 1

    replay = anon.post("/api/sync/push/", json={"changes": [item]}, headers=headers)
    assert replay.get_json()["duplicates"] == 1
    assert replay.get_json()["applied"] == 0

    peer_change = change(key="2099000202")
    assert (
        anon.post("/api/sync/push/", json={"changes": [peer_change]}, headers=peer_headers)
        .get_json()["applied"]
        == 1
    )

    pull = anon.get("/api/sync/pull/", headers=headers)
    assert pull.status_code == 200
    body = pull.get_json()
    assert body["count"] == 1
    assert body["changes"][0]["entity_key"] == "2099000202"


def test_conflict_review_and_resolution(client, anon):
    device = register(client)
    headers = {"X-Device-Token": device["token"]}

    assert (
        anon.post("/api/sync/push/", json={"changes": [change()]}, headers=headers)
        .get_json()["applied"]
        == 1
    )
    conflict_push = anon.post(
        "/api/sync/push/", json={"changes": [change()]}, headers=headers
    ).get_json()
    assert conflict_push["conflicts"] == 1

    listing = client.get("/api/sync/conflicts/").get_json()
    assert listing["ok"] is True
    assert len(listing["conflicts"]) == 1
    conflict = listing["conflicts"][0]
    assert conflict["resolution"] == "pending"

    resolved = client.post(
        f"/api/sync/conflicts/{conflict['id']}/resolve/",
        json={"strategy": "local"},
        headers=CSRF,
    )
    assert resolved.status_code == 200, resolved.get_json()
    assert resolved.get_json()["record"]["status"] == "applied"

    assert client.get("/api/sync/conflicts/").get_json()["conflicts"] == []
    assert len(client.get("/api/sync/conflicts/?all=1").get_json()["conflicts"]) == 1


def test_push_validates_authentication_and_body(client, anon):
    assert anon.post("/api/sync/push/", json={"changes": []}).status_code == 401

    device = register(client)
    headers = {"X-Device-Token": device["token"]}
    bad = anon.post("/api/sync/push/", json={"changes": "nope"}, headers=headers)
    assert bad.status_code == 400
    assert bad.get_json()["error"]["code"] == "bad_request"

    invalid_entity = anon.post(
        "/api/sync/push/",
        json={"changes": [change(entity="galaxy")]},
        headers=headers,
    ).get_json()
    assert invalid_entity["rejected"] == 1
