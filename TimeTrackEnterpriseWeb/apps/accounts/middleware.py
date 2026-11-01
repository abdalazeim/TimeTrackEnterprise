"""Account gate middleware.

Reproduces the legacy Flask ``before_request`` handlers:

* every page except a small public set requires a logged-in account;
* administrator-only API prefixes/paths are enforced;
* mutating ``/api/`` calls must carry ``X-Requested-With: StudentAttendance``
  (the CSRF guard used by the JavaScript client).
"""
from __future__ import annotations

from urllib.parse import urlsplit

from django.http import JsonResponse
from django.urls import Resolver404, resolve

from apps.core.compat import ensure_bound, g, request as compat_request, session

PUBLIC_ENDPOINTS = {
    "auth.login_page",
    "auth.login_submit",
    "views.set_language",
    "views.i18n_script",
    "views.favicon",
    "views.media_upload",
    "api.health",
    "core_health",
    "sync_capabilities",
}

PUBLIC_PATHS = {
    "/login",
    "/health/",
    "/favicon.ico",
    "/assets/i18n.js",
}

# Paired clients authenticate with ``X-Device-Token`` instead of a session; the
# synchronisation API validates the token itself, so the session gate must not
# intercept those requests.
DEVICE_TOKEN_PATHS = ("/api/sync/",)
DEVICE_TOKEN_HEADER = "X-Device-Token"

ADMIN_API_PREFIXES = ("/api/settings", "/api/uploads", "/api/users")
ADMIN_API_PATHS = {
    "/api/messages/gateway/pair",
    "/api/system/backup",
    "/api/system/shutdown",
    "/api/update/check",
    "/api/update/install",
}


def _resolve(request):
    try:
        return resolve(request.path_info)
    except Resolver404:
        return None


def _safe_next(value: str, fallback: str = "/") -> str:
    candidate = (value or "").strip()
    if not candidate or "\\" in candidate or any(ord(ch) < 32 for ch in candidate):
        return fallback
    if not candidate.startswith("/") or candidate.startswith("//"):
        return fallback
    parsed = urlsplit(candidate)
    if parsed.scheme or parsed.netloc:
        return fallback
    return candidate


def _is_admin_api_request(path: str, method: str) -> bool:
    if path in ADMIN_API_PATHS:
        return True
    if any(path == prefix or path.startswith(prefix + "/") for prefix in ADMIN_API_PREFIXES):
        return True
    if path.startswith("/api/periods") and method in ("POST", "PUT", "PATCH", "DELETE"):
        return True
    return False


def _deny(user_message: str, status: int):
    if compat_request.path.startswith("/api/"):
        code = "auth_required" if status == 401 else "forbidden"
        return JsonResponse(
            {"ok": False, "error": {"code": code, "message": user_message}},
            status=status,
            json_dumps_params={"ensure_ascii": False},
        )
    target = _safe_next(compat_request.full_path, "/")
    from django.shortcuts import redirect

    return redirect(f"/login?next={target}")


class AccountGateMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        ensure_bound(request)
        denied = self._guard(request)
        if denied is not None:
            return denied
        return self.get_response(request)

    def _guard(self, request):
        path = request.path_info

        # Static assets, the Django admin (guarded separately) and the school
        # logo/stamp are public; student photos are not.
        if path.startswith(("/static/", "/admin/", "/media/uploads/")):
            return None

        match = _resolve(request)
        if match is None:
            # Unknown path: let Django produce the usual 404 page.
            return None

        endpoint = match.url_name or match.view_name
        if endpoint in PUBLIC_ENDPOINTS or path in PUBLIC_PATHS:
            return None

        user = g.get("user")
        device_request = any(
            path.startswith(prefix) for prefix in DEVICE_TOKEN_PATHS
        ) and bool(request.headers.get(DEVICE_TOKEN_HEADER))
        if not user and not device_request:
            return _deny("يجب تسجيل الدخول للمتابعة.", 401)

        if not device_request and _is_admin_api_request(path, request.method) and user.get("role") != "admin":
            return _deny("ليست لديك صلاحية الوصول إلى هذه العملية.", 403)

        if (
            not device_request
            and path.startswith("/api/")
            and request.method in ("POST", "PUT", "PATCH", "DELETE")
            and request.headers.get("X-Requested-With") != "StudentAttendance"
        ):
            return JsonResponse(
                {
                    "ok": False,
                    "error": {
                        "code": "csrf",
                        "message": "طلب غير مصرح به. أعد تحميل الصفحة.",
                    },
                },
                status=403,
                json_dumps_params={"ensure_ascii": False},
            )

        return None
