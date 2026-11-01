"""Synchronisation JSON API.

Mounted under ``/api/sync/`` by ``config.api_urls``.

Authentication is either:

* an authenticated application session (``user_id`` in the session), used by
  the browser UI and by administrators reviewing conflicts;
* a device token sent in the ``X-Device-Token`` header, used by paired
  clients for ``push`` / ``pull``.

``capabilities`` is public so a client can discover the protocol version
before pairing.
"""
from __future__ import annotations

import json
import logging
from typing import Any

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from apps.core.compat import g
from apps.synchronization import services
from apps.synchronization.models import Device, SyncConflict

logger = logging.getLogger("attendance.sync")


def _json(payload: dict[str, Any], status: int = 200) -> JsonResponse:
    return JsonResponse(payload, status=status, json_dumps_params={"ensure_ascii": False})


def _error(message: str, status: int = 400, code: str = "bad_request") -> JsonResponse:
    return _json({"ok": False, "error": {"code": code, "message": message}}, status)


def _body(request) -> dict[str, Any]:
    if not request.body:
        return {}
    try:
        value = json.loads(request.body.decode("utf-8"))
    except (ValueError, UnicodeDecodeError) as exc:
        raise services.SyncError("جسم الطلب ليس JSON صالحًا.") from exc
    if not isinstance(value, dict):
        raise services.SyncError("جسم الطلب يجب أن يكون كائن JSON.")
    return value


def _session_user(request) -> dict | None:
    try:
        user = g.get("user")
    except Exception:  # pragma: no cover - request not bound
        user = None
    return user if user and user.get("is_active") else None


def _device(request) -> Device | None:
    return services.authenticate(request.headers.get("X-Device-Token"))


def _actor(request, device: Device | None) -> str:
    user = _session_user(request)
    if user:
        return user.get("username", "")
    if device:
        return f"device:{device.name}"
    return ""


# ---------------------------------------------------------------------------
# Public
# ---------------------------------------------------------------------------
@csrf_exempt
@require_GET
def capabilities(_request):
    return _json({"ok": True, **services.capabilities()})


# ---------------------------------------------------------------------------
# Devices
# ---------------------------------------------------------------------------
@csrf_exempt
@require_http_methods(["GET", "POST"])
def devices(request):
    user = _session_user(request)
    if not user:
        return _error("يجب تسجيل الدخول لإدارة الأجهزة.", 401, "auth_required")

    if request.method == "GET":
        queryset = Device.objects.all()
        if user.get("role") != "admin":
            queryset = queryset.filter(created_by=user.get("username", ""))
        return _json(
            {
                "ok": True,
                "devices": [
                    {
                        "id": str(device.pk),
                        "name": device.name,
                        "platform": device.platform,
                        "app_version": device.app_version,
                        "is_active": device.is_active,
                        "created_at": device.created_at.isoformat(timespec="seconds"),
                        "last_seen_at": (
                            device.last_seen_at.isoformat(timespec="seconds")
                            if device.last_seen_at
                            else None
                        ),
                    }
                    for device in queryset
                ],
            }
        )

    try:
        data = _body(request)
        device = services.register_device(
            name=str(data.get("name") or ""),
            platform=str(data.get("platform") or "desktop"),
            app_version=str(data.get("app_version") or ""),
            created_by=user.get("username", ""),
        )
    except services.SyncError as exc:
        return _error(str(exc))
    return _json(
        {
            "ok": True,
            "device": {
                "id": str(device.pk),
                "name": device.name,
                "platform": device.platform,
                "token": device.token,
            },
        },
        status=201,
    )


@csrf_exempt
@require_POST
def deactivate_device(request, device_id):
    user = _session_user(request)
    if not user or user.get("role") != "admin":
        return _error("ليست لديك صلاحية الوصول إلى هذه العملية.", 403, "forbidden")
    device = Device.objects.filter(pk=device_id).first()
    if not device:
        return _error("الجهاز غير موجود.", 404, "not_found")
    device.is_active = False
    device.save(update_fields=["is_active"])
    return _json({"ok": True})


# ---------------------------------------------------------------------------
# Push / pull
# ---------------------------------------------------------------------------
@csrf_exempt
@require_POST
def push(request):
    device = _device(request)
    if device is None:
        return _error("رمز الجهاز غير صالح.", 401, "auth_required")
    try:
        data = _body(request)
        items = data.get("changes") or data.get("items") or []
        if not isinstance(items, list):
            raise services.SyncError("changes يجب أن تكون قائمة.")
        result = services.push(device, items)
    except services.SyncError as exc:
        return _error(str(exc))
    except Exception:  # pragma: no cover - defensive
        logger.exception("Sync push failed")
        return _error("تعذر تنفيذ المزامنة.", 500, "server_error")
    return _json({"ok": True, **result})


@csrf_exempt
@require_GET
def pull(request):
    device = _device(request)
    if device is None:
        return _error("رمز الجهاز غير صالح.", 401, "auth_required")
    try:
        result = services.pull(
            device,
            since=request.GET.get("since"),
            entity=request.GET.get("entity"),
            limit=int(request.GET.get("limit") or 500),
        )
    except (services.SyncError, ValueError) as exc:
        return _error(str(exc))
    except Exception:  # pragma: no cover - defensive
        logger.exception("Sync pull failed")
        return _error("تعذر تنفيذ المزامنة.", 500, "server_error")
    return _json({"ok": True, **result})


# ---------------------------------------------------------------------------
# Conflicts
# ---------------------------------------------------------------------------
@csrf_exempt
@require_GET
def conflicts(request):
    if not _session_user(request) and not _device(request):
        return _error("يجب تسجيل الدخول للمتابعة.", 401, "auth_required")
    include_resolved = request.GET.get("all") == "1"
    queryset = SyncConflict.objects.select_related("record")
    if not include_resolved:
        queryset = queryset.filter(resolution="pending")
    return _json(
        {
            "ok": True,
            "conflicts": [services.serialise_conflict(item) for item in queryset],
        }
    )


@csrf_exempt
@require_POST
def resolve_conflict(request, conflict_id):
    user = _session_user(request)
    if not user or user.get("role") != "admin":
        return _error("ليست لديك صلاحية الوصول إلى هذه العملية.", 403, "forbidden")
    conflict = SyncConflict.objects.select_related("record").filter(pk=conflict_id).first()
    if not conflict:
        return _error("التعارض غير موجود.", 404, "not_found")
    try:
        data = _body(request)
        record = services.resolve_conflict(
            conflict,
            strategy=str(data.get("strategy") or ""),
            payload=data.get("payload"),
            actor=user.get("username", ""),
        )
    except services.SyncError as exc:
        return _error(str(exc))
    return _json(
        {
            "ok": True,
            "record": {
                "id": str(record.pk),
                "status": record.status,
                "server_revision": record.server_revision,
            },
        }
    )
