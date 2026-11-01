"""HTTP error responses matching the legacy Flask handlers."""
from __future__ import annotations

import logging

from django.http import HttpResponse, JsonResponse

logger = logging.getLogger("attendance")

API_CODES = {
    400: "bad_request",
    401: "auth_required",
    403: "forbidden",
    404: "not_found",
    405: "method_not_allowed",
    409: "conflict",
    413: "too_large",
    429: "too_many_requests",
    500: "server_error",
}

HTML_MESSAGES = {
    400: "تعذر إتمام العملية.",
    401: "يجب تسجيل الدخول للمتابعة.",
    403: "ليست لديك صلاحية الوصول إلى هذه الصفحة.",
    404: "الصفحة غير موجودة.",
    405: "طريقة الطلب غير مسموح بها.",
    409: "تعارض في البيانات.",
    413: "حجم الطلب كبير جدًا.",
    429: "محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.",
    500: "حدث خطأ داخلي غير متوقع.",
}

API_MESSAGES = {
    400: "الطلب غير صالح.",
    401: "يجب تسجيل الدخول للمتابعة.",
    403: "ليست لديك صلاحية الوصول إلى هذه العملية.",
    404: "المسار غير موجود.",
    405: "طريقة الطلب غير مسموح بها.",
    409: "تعارض في البيانات.",
    413: "حجم الملف كبير جدًا (الحد 30 ميغابايت).",
    429: "محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.",
    500: "حدث خطأ داخلي غير متوقع. راجع سجل التطبيق.",
}


def wants_json(request) -> bool:
    path = getattr(request, "path", "") or ""
    if path.startswith("/api/"):
        return True
    accept = (getattr(request, "headers", {}) or {}).get("Accept", "")
    return "application/json" in accept and "text/html" not in accept


def error_response(request, status: int, message: str | None = None):
    status = int(status)
    if wants_json(request):
        payload = {
            "ok": False,
            "error": {
                "code": API_CODES.get(status, "error"),
                "message": message or API_MESSAGES.get(status, HTML_MESSAGES.get(status, "خطأ.")),
            },
        }
        return JsonResponse(payload, status=status, json_dumps_params={"ensure_ascii": False})

    from apps.core.templating import render_compat_template

    context = {
        "code": status,
        "message": message or HTML_MESSAGES.get(status, "تعذر إتمام العملية."),
        "page_title": HTML_MESSAGES.get(status, "خطأ"),
    }
    try:
        response = render_compat_template("error.html", context)
        response.status_code = status
        return response
    except Exception:  # pragma: no cover - template failure fallback
        logger.exception("Failed to render the error page")
        return HttpResponse(
            f"<!doctype html><meta charset='utf-8'><h1>{status}</h1>"
            f"<p>{context['message']}</p>",
            status=status,
            content_type="text/html; charset=utf-8",
        )


# ---------------------------------------------------------------------------
# Django error handlers (wired in ``config/urls.py``)
# ---------------------------------------------------------------------------
def handler400(request, exception=None):
    return error_response(request, 400)


def handler403(request, exception=None):
    return error_response(request, 403)


def handler404(request, exception=None):
    return error_response(request, 404)


def handler500(request, *args, **kwargs):  # noqa: ARG001 - Django passes just the request
    return error_response(request, 500)
