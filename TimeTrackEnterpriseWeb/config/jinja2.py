"""Jinja2 environment used by the Django template backend.

The migrated templates keep their legacy names (``dashboard.html``,
``base.html``, ``print_sheet.html`` ...).  :class:`LayoutLoader` resolves
those names inside the organised ``templates/`` tree, so no template
content had to be rewritten for the new folder layout.
"""
from __future__ import annotations

from pathlib import Path

from jinja2 import BaseLoader, Environment, FileSystemLoader, TemplateNotFound

# Search order matters: explicit sub-folders first, then the tree root.
_SEARCH_DIRS = (
    "",
    "pages",
    "base",
    "print",
    "partials",
    "components",
    "pages/errors",
)


class LayoutLoader(BaseLoader):
    """Resolve flat legacy names against the organised template tree."""

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)
        self._loader = FileSystemLoader(str(self.root))

    def get_source(self, environment, template):  # noqa: A003 - Jinja API
        for prefix in _SEARCH_DIRS:
            candidate = f"{prefix}/{template}" if prefix else template
            try:
                return self._loader.get_source(environment, candidate)
            except TemplateNotFound:
                continue
        raise TemplateNotFound(template)

    def list_templates(self):
        return self._loader.list_templates()


def environment(**options) -> Environment:
    """Build the Jinja2 environment (referenced from ``settings.TEMPLATES``)."""
    from django.conf import settings

    from apps.core import i18n
    from apps.core.compat import url_for
    from apps.core.templating import FILTERS, GLOBALS
    from apps.core.utils import month_label, short_date

    options.pop("loader", None)
    options.setdefault("autoescape", True)
    options.setdefault("keep_trailing_newline", True)

    root = Path(settings.BASE_DIR) / "templates"
    env = Environment(loader=LayoutLoader(root), **options)

    def csrf_token() -> str:
        try:
            from apps.accounts.services import ensure_csrf_token

            return ensure_csrf_token()
        except Exception:  # pragma: no cover - session-less rendering
            return ""

    def get_flashed_messages(*_args, **_kwargs):
        return []

    env.globals.update(
        {
            "url_for": url_for,
            "t": i18n.translate,
            "csrf_token": csrf_token,
            "get_flashed_messages": get_flashed_messages,
            "short_date": short_date,
            "month_label": month_label,
            "static": lambda path: url_for("static", filename=path),
        }
    )
    env.filters.update(
        {
            "t": i18n.t_filter,
            "short_date": short_date,
            "month_label": month_label,
        }
    )

    # Filters/globals registered by the migrated blueprints at import time.
    env.filters.update(FILTERS)
    env.globals.update(GLOBALS)
    try:  # make sure the blueprint-level filters are registered
        from apps.modules import views as _views  # noqa: F401
    except Exception:  # pragma: no cover - import order at boot
        pass
    env.filters.update(FILTERS)
    env.globals.update(GLOBALS)

    return env
