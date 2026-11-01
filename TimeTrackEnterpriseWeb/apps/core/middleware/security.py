"""Security headers middleware.

``CompatRequestMiddleware`` already adds the legacy headers to every
response.  This middleware exists for deployments that serve native Django
views (admin, REST) and builds the policy from the settings tuples so the
values stay in one place.
"""
from __future__ import annotations

from django.conf import settings


def _policy(directive: str, setting_name: str) -> str | None:
    values = getattr(settings, setting_name, None)
    if not values:
        return None
    return f"{directive} {' '.join(values)}"


def build_content_security_policy() -> str:
    directives = [
        _policy("default-src", "CSP_DEFAULT_SRC"),
        _policy("script-src", "CSP_SCRIPT_SRC"),
        _policy("style-src", "CSP_STYLE_SRC"),
        _policy("img-src", "CSP_IMG_SRC"),
        _policy("font-src", "CSP_FONT_SRC"),
        _policy("connect-src", "CSP_CONNECT_SRC"),
        _policy("media-src", "CSP_MEDIA_SRC"),
        _policy("object-src", "CSP_OBJECT_SRC"),
        _policy("frame-ancestors", "CSP_FRAME_ANCESTORS"),
        _policy("base-uri", "CSP_BASE_URI"),
    ]
    return "; ".join(item for item in directives if item)


class SecurityHeadersMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        policy = build_content_security_policy()
        if policy:
            response.headers.setdefault("Content-Security-Policy", policy)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "same-origin")
        response.headers.setdefault(
            "Permissions-Policy", "camera=(self), microphone=(), geolocation=()"
        )
        if request.path.startswith("/api/"):
            response.headers.setdefault("Cache-Control", "no-store")
        return response
