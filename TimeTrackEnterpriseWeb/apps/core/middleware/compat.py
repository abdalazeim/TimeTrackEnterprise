"""Request/response bridge for the migrated Flask-style modules."""
from __future__ import annotations

import logging

from django.conf import settings
from django.utils import translation

from apps.core import i18n
from apps.core.compat import bind_request, close_db_compat, g, unbind_request
from apps.core.errors import error_response

logger = logging.getLogger("attendance")

_LEGACY_CSP = (
    "default-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; "
    "style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; "
    "font-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'"
)


class CompatRequestMiddleware:
    """Set up the Flask-compatible context and finalise the response.

    * binds ``request`` / ``g`` / ``session`` for the migrated modules;
    * resolves the interface language from the ``attendance_lang`` cookie;
    * loads the session user into ``g.user``;
    * localises HTML/JSON responses (Arabic, English, French);
    * adds the legacy security headers and closes the SQLite connection.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        bind_request(request)
        lang = i18n.set_current_lang(i18n.normalize_lang(request.COOKIES.get(i18n.LANG_COOKIE)))
        request.LANGUAGE_CODE = lang
        try:
            translation.activate(lang)
        except Exception:  # pragma: no cover - unsupported Django locale
            pass
        g.lang = lang
        g.lang_dir = i18n.lang_dir(lang)
        self._load_user(request)

        try:
            response = self.get_response(request)
        except Exception as exc:  # pragma: no cover - last-resort guard
            response = self.process_exception(request, exc)
            if response is None:
                raise
        finally:
            close_db_compat()
            unbind_request()

        self._finalize(request, response, lang)
        return response

    def process_exception(self, request, exception):
        logger.exception("Unhandled exception on %s", getattr(request, "path", "?"))
        return error_response(request, 500)

    # -- helpers --------------------------------------------------------
    @staticmethod
    def _load_user(request) -> None:
        from apps.accounts.services import get_user

        user_id = request.session.get("user_id")
        if not user_id:
            return
        try:
            user = get_user(user_id)
        except Exception:  # pragma: no cover - database hiccup
            logger.exception("Unable to load the session user")
            user = None
        if user and user.get("is_active"):
            g.user = user
        else:
            request.session.flush()

    @staticmethod
    def _finalize(request, response, lang: str) -> None:
        try:
            i18n.localize_response(response, lang)
        except Exception:  # pragma: no cover - never break a response
            logger.debug("Response localisation failed", exc_info=True)

        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "same-origin")
        csp = getattr(settings, "CONTENT_SECURITY_POLICY", "") or _LEGACY_CSP
        response.headers.setdefault("Content-Security-Policy", csp)
        if response.get("Content-Language") is None:
            response["Content-Language"] = lang
        if getattr(request, "path", "").startswith("/api/"):
            response.headers.setdefault("Cache-Control", "no-store")
        vary = response.get("Vary")
        if vary:
            if "Cookie" not in vary:
                response["Vary"] = f"{vary}, Cookie"
        else:
            response["Vary"] = "Cookie"
