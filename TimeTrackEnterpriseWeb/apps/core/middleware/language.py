"""Language switching middleware (``attendance_lang`` cookie)."""
from __future__ import annotations

from django.utils import translation

from apps.core import i18n


class LanguageSwitchMiddleware:
    """Activate the interface language early for native Django views.

    ``CompatRequestMiddleware`` does the same for the migrated Flask-style
    handlers; this class is kept for deployments that use Django views only
    (for example the admin or a future REST layer).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        lang = i18n.set_current_lang(
            i18n.normalize_lang(request.COOKIES.get(i18n.LANG_COOKIE))
        )
        request.LANGUAGE_CODE = lang
        try:
            translation.activate(lang)
        except Exception:  # pragma: no cover - unsupported locale
            pass

        response = self.get_response(request)

        if response.get("Content-Language") is None:
            response["Content-Language"] = lang
        vary = response.get("Vary")
        if vary:
            if "Cookie" not in vary:
                response["Vary"] = f"{vary}, Cookie"
        else:
            response["Vary"] = "Cookie"
        return response
