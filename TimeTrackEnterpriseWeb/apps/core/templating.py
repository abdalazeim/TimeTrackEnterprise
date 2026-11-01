"""Template rendering bridge for the migrated Flask-style views.

The legacy application rendered flat template names such as
``dashboard.html``.  The new layout groups templates into ``base/``,
``pages/``, ``print/`` and ``partials/``.  A custom Jinja2 loader (see
``config/jinja2.py``) resolves those names, and this module builds the
shared context that the legacy Flask context processors used to inject.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Callable

from django.conf import settings
from django.http import HttpResponse
from django.template import loader

logger = logging.getLogger("attendance")

FILTERS: dict[str, Callable] = {}
GLOBALS: dict[str, Callable] = {}


def register_filter(name: str, func: Callable) -> None:
    FILTERS[name] = func
    _apply_to_live_environment("filters", name, func)


def register_global(name: str, func: Callable) -> None:
    GLOBALS[name] = func
    _apply_to_live_environment("globals", name, func)


def _apply_to_live_environment(kind: str, name: str, func: Callable) -> None:
    try:
        engines = loader.engines
        backend = engines["jinja2"]
    except Exception:
        return
    environment = getattr(backend, "env", None)
    if environment is None:
        return
    getattr(environment, kind)[name] = func


def base_context() -> dict[str, Any]:
    """Return the globals every legacy template expects."""
    from apps.core import config as legacy_config
    from apps.core import i18n
    from apps.core.db import get_db, get_settings

    lang = i18n.current_lang()
    settings_map: dict[str, str] = {}
    try:
        settings_map = get_settings(get_db())
    except Exception:  # pragma: no cover - database not ready yet
        logger.debug("Settings unavailable while rendering a template", exc_info=True)

    color_theme = settings_map.get("color_theme", legacy_config.DEFAULT_COLOR_THEME)
    if color_theme not in legacy_config.COLOR_THEMES:
        color_theme = legacy_config.DEFAULT_COLOR_THEME

    current_user = None
    try:
        from apps.core.compat import g

        current_user = g.get("user")
    except Exception:
        current_user = None

    csrf_value = ""
    try:
        from apps.accounts.services import ensure_csrf_token

        csrf_value = ensure_csrf_token()
    except Exception:  # pragma: no cover - session-less rendering
        csrf_value = ""

    role_label = ""
    if current_user:
        role_label = legacy_config.ROLE_LABELS.get(current_user.get("role", ""), "")

    context: dict[str, Any] = {
        **legacy_config.app_metadata(lang),
        "lang": lang,
        "dir": i18n.lang_dir(lang),
        "lang_options": i18n.LANGUAGES,
        "color_theme": color_theme,
        "settings": settings_map,
        "school_name": settings_map.get("school_name", ""),
        "academic_year": settings_map.get("academic_year", ""),
        "current_user": current_user,
        "is_admin": bool(current_user and current_user.get("role") == "admin"),
        "role_label": role_label,
        "csrf_token_value": csrf_value,
        "request": None,
        "app_version": legacy_config.APP_VERSION,
        "gateway_app_name": legacy_config.GATEWAY_APP_NAME,
        "gateway_app_version": legacy_config.GATEWAY_APP_VERSION,
        "gateway_app_download_url": legacy_config.GATEWAY_APP_DOWNLOAD_URL,
        "whatsapp_download_url": legacy_config.WHATSAPP_DOWNLOAD_URL,
        "current_year": __import__("datetime").datetime.now().year,
    }

    try:
        from apps.modules.services.scanner_bridge_service import MAX_PHONES

        context["scan_phone_limit"] = MAX_PHONES
    except Exception:  # pragma: no cover - optional dependency
        context["scan_phone_limit"] = 4

    return context


def render_compat_template(
    template_name: str,
    context: dict[str, Any] | None = None,
    *,
    using: str = "jinja2",
) -> HttpResponse:
    """Render a legacy template name through the Jinja2 backend."""
    merged = base_context()
    merged["request"] = _current_request_adapter()
    if context:
        merged.update(context)
    if merged.get("request") is None:
        merged.pop("request", None)

    backend_template = loader.get_template(template_name, using=using)
    html = backend_template.template.render(merged)
    return HttpResponse(html, content_type="text/html; charset=utf-8")


def _current_request_adapter():
    try:
        from apps.core.compat import request as compat_request

        _ = compat_request.method
        return compat_request
    except Exception:
        return None


def template_exists(template_name: str, using: str = "jinja2") -> bool:
    try:
        loader.get_template(template_name, using=using)
        return True
    except Exception:
        return False


def static_path(*parts: str) -> str:
    base = Path(settings.BASE_DIR) / "static"
    return str(base.joinpath(*parts))
