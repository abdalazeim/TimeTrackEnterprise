"""URL patterns for ``/api/sync/``."""
from __future__ import annotations

from django.urls import path

from apps.synchronization import api

urlpatterns = [
    path("capabilities/", api.capabilities, name="sync_capabilities"),
    path("devices/", api.devices, name="sync_devices"),
    path("devices/<uuid:device_id>/deactivate/", api.deactivate_device, name="sync_device_deactivate"),
    path("push/", api.push, name="sync_push"),
    path("pull/", api.pull, name="sync_pull"),
    path("conflicts/", api.conflicts, name="sync_conflicts"),
    path("conflicts/<uuid:conflict_id>/resolve/", api.resolve_conflict, name="sync_conflict_resolve"),
]
