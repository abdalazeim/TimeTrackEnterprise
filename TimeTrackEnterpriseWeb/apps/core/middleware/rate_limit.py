"""In-memory rate limiting for the login endpoint.

The login blueprint already throttles failed attempts per
``username|remote_addr``.  This middleware adds a coarse per-IP guard for
deployments that expose the login form through a reverse proxy, and returns a
localised 429 page instead of letting a burst reach the view.
"""
from __future__ import annotations

import time
from collections import defaultdict
from threading import Lock

from django.http import JsonResponse

from apps.core.errors import error_response

LOGIN_PATH = "/login"
WINDOW_SECONDS = 300
MAX_PER_IP = 20


class RateLimitMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        self._lock = Lock()
        self._attempts: dict[str, list[float]] = defaultdict(list)
        self.window = WINDOW_SECONDS
        self.limit = MAX_PER_IP

    def __call__(self, request):
        if request.path == LOGIN_PATH and request.method == "POST":
            key = self._client_ip(request)
            now = time.time()
            with self._lock:
                stamps = [stamp for stamp in self._attempts[key] if now - stamp < self.window]
                self._attempts[key] = stamps
                if len(stamps) >= self.limit:
                    retry_after = max(1, int(self.window - (now - stamps[0])))
                    return self._too_many(retry_after)
                stamps.append(now)
            # Opportunistic cleanup so the dict cannot grow forever.
            if len(self._attempts) > 5000:
                with self._lock:
                    for stale in [k for k, v in self._attempts.items() if not v]:
                        self._attempts.pop(stale, None)
        return self.get_response(request)

    @staticmethod
    def _client_ip(request) -> str:
        forwarded = (request.META.get("HTTP_X_FORWARDED_FOR") or "").split(",")[0].strip()
        return forwarded or request.META.get("REMOTE_ADDR") or "unknown"

    @staticmethod
    def _too_many(retry_after: int):
        message = "محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا."
        response = error_response(_DummyRequest(), 429, message)
        response["Retry-After"] = str(retry_after)
        return response


class _DummyRequest:
    """Minimal request facade for the error renderer (no API path)."""

    path = LOGIN_PATH
    headers: dict[str, str] = {}

    def __getattr__(self, name):
        raise AttributeError(name)
