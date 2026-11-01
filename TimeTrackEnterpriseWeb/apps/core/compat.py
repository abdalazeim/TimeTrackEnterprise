"""Flask-compatible layer implemented on top of Django.

The functional modules of this project (attendance, slips, messaging,
reports, printing, updates, ...) were migrated from a Flask application.
Their business logic is preserved byte-for-byte; only the framework
plumbing is replaced.  This module supplies the small subset of the Flask
API that those modules use:

* ``Blueprint`` with ``get/post/put/patch/delete`` decorators that turn
  Flask rules into Django URL patterns (see :func:`urlpatterns_for`).
* request-scoped proxies: ``request``, ``g``, ``session`` and
  ``current_app``.
* response helpers: ``jsonify``, ``Response``, ``send_file``,
  ``send_from_directory``, ``render_template``, ``redirect``, ``abort``
  and ``url_for``.

Nothing here depends on Flask itself.
"""
from __future__ import annotations

import json
import logging
import re
from contextvars import ContextVar
from pathlib import Path
from typing import Any, Callable, Iterable
from urllib.parse import quote

from django.conf import settings
from django.http import (
    FileResponse,
    Http404,
    HttpResponse,
    HttpResponseRedirect,
    StreamingHttpResponse,
)
from django.http.response import HttpResponseBase
from django.urls import NoReverseMatch, path as django_path, reverse
from django.views.decorators.csrf import csrf_exempt

logger = logging.getLogger("attendance")

# ---------------------------------------------------------------------------
# Request state
# ---------------------------------------------------------------------------

_STATE: ContextVar[dict[str, Any] | None] = ContextVar("attendance_compat_state", default=None)


class _UnboundRequest(RuntimeError):
    def __init__(self) -> None:
        super().__init__("Working outside of request context.")


def _state() -> dict[str, Any]:
    state = _STATE.get()
    if state is None:
        raise _UnboundRequest()
    return state


def bind_request(request) -> dict[str, Any]:
    """Create the request-scoped state used by the proxies below."""
    state = {
        "django_request": request,
        "request": FlaskRequest(request),
        "g": _Namespace(),
    }
    _STATE.set(state)
    return state


def ensure_bound(request) -> dict[str, Any]:
    """Bind ``request`` unless the same request is already bound."""
    state = _STATE.get()
    if state is None or state["django_request"] is not request:
        return bind_request(request)
    return state


def unbind_request() -> None:
    _STATE.set(None)


def close_db_compat() -> None:
    """Close the per-thread SQLite connection at the end of a request."""
    from apps.core.db import close_db

    try:
        close_db()
    except Exception:  # pragma: no cover - defensive
        logger.debug("Failed to close the compatibility database", exc_info=True)


def current_django_request():
    return _state()["django_request"]


# ---------------------------------------------------------------------------
# Small containers
# ---------------------------------------------------------------------------


class _Namespace:
    """Attribute + mapping container used for ``g``."""

    def __init__(self) -> None:
        object.__setattr__(self, "_store", {})

    def __getattr__(self, name: str) -> Any:
        try:
            return object.__getattribute__(self, "_store")[name]
        except KeyError as exc:
            raise AttributeError(name) from exc

    def __setattr__(self, name: str, value: Any) -> None:
        object.__getattribute__(self, "_store")[name] = value

    def __delattr__(self, name: str) -> None:
        object.__getattribute__(self, "_store").pop(name, None)

    def get(self, name: str, default: Any = None) -> Any:
        return object.__getattribute__(self, "_store").get(name, default)

    def pop(self, name: str, default: Any = None) -> Any:
        return object.__getattribute__(self, "_store").pop(name, default)

    def setdefault(self, name: str, default: Any = None) -> Any:
        return object.__getattribute__(self, "_store").setdefault(name, default)

    def __getitem__(self, name: str) -> Any:
        return object.__getattribute__(self, "_store")[name]

    def __setitem__(self, name: str, value: Any) -> None:
        object.__getattribute__(self, "_store")[name] = value

    def __contains__(self, name: object) -> bool:
        return name in object.__getattribute__(self, "_store")

    def __iter__(self):
        return iter(object.__getattribute__(self, "_store"))

    def __len__(self) -> int:
        return len(object.__getattribute__(self, "_store"))


class Args:
    """Flask-like view over a Django ``QueryDict`` (args or form)."""

    def __init__(self, data) -> None:
        self._data = data

    def get(self, key: str, default: Any = None, type: Callable[[Any], Any] | None = None) -> Any:
        if key not in self._data:
            return default
        value = self._data.get(key)
        if type is None:
            return value
        try:
            return type(value)
        except (TypeError, ValueError):
            return default

    def getlist(self, key: str) -> list[str]:
        getter = getattr(self._data, "getlist", None)
        if getter:
            return list(getter(key))
        value = self._data.get(key)
        return [] if value is None else [value]

    def __getitem__(self, key: str) -> Any:
        return self._data[key]

    def __contains__(self, key: object) -> bool:
        return key in self._data

    def __iter__(self):
        return iter(self._data)

    def __len__(self) -> int:
        return len(self._data)

    def keys(self):
        return self._data.keys()

    def values(self):
        return self._data.values()

    def items(self):
        return self._data.items()

    def to_dict(self, flat: bool = True) -> dict:
        convert = getattr(self._data, "lists", None)
        if flat or convert is None:
            return dict(self._data.items())
        return dict(convert())


class FileProxy:
    """Expose a Django ``UploadedFile`` with Flask's ``filename`` attribute."""

    def __init__(self, upload) -> None:
        self._upload = upload

    @property
    def filename(self) -> str:
        return getattr(self._upload, "name", "") or ""

    def read(self, *args, **kwargs):
        return self._upload.read(*args, **kwargs)

    def save(self, *args, **kwargs):
        return self._upload.save(*args, **kwargs)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._upload, name)


class Files:
    def __init__(self, files) -> None:
        self._files = files

    def get(self, key: str, default: Any = None) -> Any:
        upload = self._files.get(key) if key in self._files else None
        return FileProxy(upload) if upload is not None else default

    def __contains__(self, key: object) -> bool:
        return key in self._files

    def __iter__(self):
        return iter(self._files)

    def items(self):
        return [(key, FileProxy(value)) for key, value in self._files.items()]

    def keys(self):
        return self._files.keys()


# ---------------------------------------------------------------------------
# Request wrapper
# ---------------------------------------------------------------------------


class FlaskRequest:
    """Adapter exposing the Flask request interface used by the modules."""

    def __init__(self, request) -> None:
        self._request = request
        self.args = Args(request.GET)
        self.form = Args(request.POST)

    # -- basics ---------------------------------------------------------
    @property
    def method(self) -> str:
        return self._request.method

    @property
    def path(self) -> str:
        return self._request.path

    @property
    def full_path(self) -> str:
        return self._request.get_full_path()

    @property
    def query_string(self) -> bytes:
        return (self._request.META.get("QUERY_STRING") or "").encode("latin-1", "replace")

    @property
    def host(self) -> str:
        return self._request.get_host()

    @property
    def host_url(self) -> str:
        return self._request.build_absolute_uri("/")

    @property
    def url(self) -> str:
        return self._request.build_absolute_uri()

    @property
    def base_url(self) -> str:
        return self._request.build_absolute_uri(self._request.path)

    @property
    def url_root(self) -> str:
        return self.host_url

    @property
    def remote_addr(self) -> str:
        return self._request.META.get("REMOTE_ADDR") or ""

    @property
    def referrer(self) -> str | None:
        return self._request.META.get("HTTP_REFERER")

    @property
    def headers(self):
        return self._request.headers

    @property
    def cookies(self):
        return self._request.COOKIES

    @property
    def files(self) -> Files:
        return Files(self._request.FILES)

    @property
    def endpoint(self) -> str | None:
        match = getattr(self._request, "resolver_match", None)
        if match is None:
            return None
        return match.url_name or match.view_name

    @property
    def blueprint(self) -> str | None:
        endpoint = self.endpoint or ""
        return endpoint.split(".", 1)[0] if "." in endpoint else None

    @property
    def is_json(self) -> bool:
        return "application/json" in (self._request.META.get("CONTENT_TYPE") or "").lower()

    @property
    def content_type(self) -> str:
        return self._request.META.get("CONTENT_TYPE") or ""

    def get_json(self, force: bool = False, silent: bool = False, cache: bool = True):
        try:
            if not force and not self.is_json:
                if silent:
                    return None
                raise ValueError("Request is not JSON")
            raw = self._request.body
            if not raw:
                return None
            return json.loads(raw.decode("utf-8"))
        except Exception:
            if silent:
                return None
            raise

    def get_data(self, cache: bool = True, as_text: bool = False):
        raw = self._request.body
        return raw.decode("utf-8", "replace") if as_text else raw

    def __getattr__(self, name: str) -> Any:
        return getattr(self._request, name)


class _RequestProxy:
    def __getattr__(self, name: str) -> Any:
        return getattr(_state()["request"], name)

    def __repr__(self) -> str:  # pragma: no cover - debugging helper
        try:
            return f"<Request {self.method} {self.path}>"
        except Exception:
            return "<unbound Request>"


class _GProxy:
    def __getattr__(self, name: str) -> Any:
        return getattr(_state()["g"], name)

    def __setattr__(self, name: str, value: Any) -> None:
        setattr(_state()["g"], name, value)

    def __delattr__(self, name: str) -> None:
        delattr(_state()["g"], name)

    def get(self, name: str, default: Any = None) -> Any:
        return _state()["g"].get(name, default)

    def pop(self, name: str, default: Any = None) -> Any:
        return _state()["g"].pop(name, default)

    def setdefault(self, name: str, default: Any = None) -> Any:
        return _state()["g"].setdefault(name, default)

    def __getitem__(self, name: str) -> Any:
        return _state()["g"][name]

    def __setitem__(self, name: str, value: Any) -> None:
        _state()["g"][name] = value

    def __contains__(self, name: object) -> bool:
        return name in _state()["g"]

    def __iter__(self):
        return iter(_state()["g"])


class _SessionProxy:
    def _session(self):
        return _state()["django_request"].session

    def get(self, key: str, default: Any = None) -> Any:
        return self._session().get(key, default)

    def pop(self, key: str, default: Any = None) -> Any:
        return self._session().pop(key, default)

    def setdefault(self, key: str, default: Any = None) -> Any:
        return self._session().setdefault(key, default)

    def clear(self) -> None:
        self._session().flush()

    def __getitem__(self, key: str) -> Any:
        return self._session()[key]

    def __setitem__(self, key: str, value: Any) -> None:
        self._session()[key] = value

    def __delitem__(self, key: str) -> None:
        del self._session()[key]

    def __contains__(self, key: object) -> bool:
        return key in self._session()

    def __iter__(self):
        return iter(self._session())

    def __len__(self) -> int:
        return len(self._session())

    def keys(self):
        return self._session().keys()

    def items(self):
        return self._session().items()

    @property
    def modified(self) -> bool:
        return True

    @property
    def permanent(self) -> bool:
        return True

    @permanent.setter
    def permanent(self, _value) -> None:  # Flask-compatible no-op
        return None


request = _RequestProxy()
g = _GProxy()
session = _SessionProxy()


# ---------------------------------------------------------------------------
# Application object (``current_app``)
# ---------------------------------------------------------------------------


def _config_from_settings() -> dict[str, Any]:
    from apps.core import config as legacy_config

    data_dir = Path(getattr(settings, "DATA_DIR", Path(settings.BASE_DIR) / "data"))
    db_path = getattr(settings, "DB_PATH", None)
    if not db_path:
        db_path = settings.DATABASES["default"].get("NAME") or str(
            data_dir / "TimeTrackEnterprise.db"
        )
    return {
        "DATA_DIR": str(data_dir),
        "DB_PATH": str(db_path),
        "PHOTOS_DIR": str(getattr(settings, "PHOTOS_DIR", data_dir / "photos")),
        "UPLOADS_DIR": str(getattr(settings, "UPLOADS_DIR", data_dir / "uploads")),
        "TMP_DIR": str(getattr(settings, "TMP_DIR", data_dir / "tmp")),
        "LOGS_DIR": str(getattr(settings, "LOGS_DIR", data_dir / "logs")),
        "UPDATES_DIR": str(getattr(settings, "UPDATES_DIR", data_dir / "updates")),
        "SECRET_KEY": settings.SECRET_KEY,
        "APP_VERSION": getattr(settings, "APP_VERSION", legacy_config.APP_VERSION),
        "UPDATE_FEED_URL": getattr(settings, "UPDATE_FEED_URL", legacy_config.UPDATE_FEED_URL),
        "UPDATE_PUBLIC_KEY": getattr(settings, "UPDATE_PUBLIC_KEY", legacy_config.UPDATE_PUBLIC_KEY),
        "UPDATE_CHECK_INTERVAL": getattr(
            settings, "UPDATE_CHECK_INTERVAL", legacy_config.UPDATE_CHECK_INTERVAL
        ),
        "SCHEDULER_INTERVAL": getattr(settings, "SCHEDULER_INTERVAL", 25),
        "DISABLE_SCHEDULER": getattr(settings, "DISABLE_SCHEDULER", False),
        "TESTING": getattr(settings, "TESTING", False),
        "MAX_CONTENT_LENGTH": getattr(settings, "MAX_CONTENT_LENGTH", 30 * 1024 * 1024),
        "DEBUG": settings.DEBUG,
    }


class FlaskResponse(HttpResponse):
    """``HttpResponse`` accepting Flask's ``mimetype`` keyword."""

    def __init__(
        self,
        body: Any = b"",
        status: int | None = None,
        headers: dict[str, str] | None = None,
        mimetype: str | None = None,
        content_type: str | None = None,
        direct_passthrough: bool = False,
    ) -> None:
        if isinstance(body, str):
            body = body.encode("utf-8")
        elif isinstance(body, (dict, list)):
            body = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            content_type = content_type or "application/json"
        super().__init__(body, status=status, content_type=content_type or mimetype, headers=headers)
        self.direct_passthrough = direct_passthrough


class CompatApp:
    """Minimal application object shared by request handlers and workers."""

    def __init__(self) -> None:
        self.config: dict[str, Any] = {}
        self.extensions: dict[str, Any] = {}
        self.response_class = FlaskResponse
        self.logger = logger
        self.name = "attendance"

    def _get_current_object(self) -> "CompatApp":
        return self

    @property
    def static_folder(self) -> str:
        dirs = list(getattr(settings, "STATICFILES_DIRS", []) or [])
        if dirs:
            return str(dirs[0])
        return str(Path(settings.BASE_DIR) / "static")

    # Flask extension hooks are no-ops in Django; kept for API compatibility.
    def before_request(self, func):
        return func

    def after_request(self, func):
        return func

    def teardown_appcontext(self, func):
        return func

    def context_processor(self, func):
        return func

    def shell_context_processor(self, func):
        return func

    def template_global(self, name=None):
        def decorator(func):
            from apps.core.templating import register_global

            register_global(name or func.__name__, func)
            return func

        return decorator

    def template_filter(self, name=None):
        def decorator(func):
            from apps.core.templating import register_filter

            register_filter(name or func.__name__, func)
            return func

        return decorator

    def refresh(self) -> None:
        self.config = _config_from_settings()

    def app_context(self):
        """Flask-compatible application context (a no-op in Django).

        Background workers written for Flask use ``with app.app_context():``
        around their work; Django has no such context, so a null context
        manager is enough to keep them unchanged.
        """
        from contextlib import nullcontext

        if not self.config:
            self.config = _config_from_settings()
        return nullcontext()


class _CurrentAppProxy:
    def __getattr__(self, name: str) -> Any:
        return getattr(get_app(), name)

    def __repr__(self) -> str:  # pragma: no cover - debugging helper
        return "<current_app (Django compatibility)>"


_app: CompatApp | None = None


def get_app() -> CompatApp:
    global _app
    if _app is None:
        _app = CompatApp()
    if not _app.config:
        _app.config = _config_from_settings()
    return _app


current_app = _CurrentAppProxy()


# ---------------------------------------------------------------------------
# Blueprint -> Django URL patterns
# ---------------------------------------------------------------------------

_RULE_RE = re.compile(r"<(?:(?P<converter>[a-zA-Z_]+):)?(?P<name>[a-zA-Z_][a-zA-Z0-9_]*)>")
_CONVERTERS = {
    "string": "str",
    "str": "str",
    "int": "int",
    "float": "float",
    "path": "path",
    "uuid": "uuid",
    "any": "str",
}


def to_django_rule(rule: str) -> str:
    def replace(match: re.Match[str]) -> str:
        converter = (match.group("converter") or "string").lower()
        return f"<{_CONVERTERS.get(converter, 'str')}:{match.group('name')}>"

    return _RULE_RE.sub(replace, rule)


class HTTPError(Exception):
    def __init__(self, code: int = 500, description: str | None = None) -> None:
        self.code = int(code)
        self.description = description or _DEFAULT_ERRORS.get(self.code, "حدث خطأ غير متوقع.")
        super().__init__(self.description)


_DEFAULT_ERRORS = {
    400: "الطلب غير صالح.",
    401: "يجب تسجيل الدخول للمتابعة.",
    403: "ليست لديك صلاحية الوصول إلى هذه الصفحة.",
    404: "الصفحة غير موجودة.",
    405: "طريقة الطلب غير مسموح بها.",
    409: "تعارض في البيانات.",
    413: "حجم الطلب كبير جدًا.",
    500: "حدث خطأ داخلي غير متوقع.",
}


class Blueprint:
    def __init__(self, name: str, import_name: str = "", url_prefix: str = "") -> None:
        self.name = name
        self.import_name = import_name
        self.url_prefix = url_prefix or ""
        self._routes: list[tuple[str, str, Callable, tuple[str, ...]]] = []
        self._error_handlers: dict[type[BaseException], Callable] = {}
        self._filters: dict[str, Callable] = {}
        self._before: list[Callable] = []
        self._after: list[Callable] = []
        self._context_processors: list[Callable] = []

    # -- route registration --------------------------------------------
    def route(self, rule: str, methods: Iterable[str] = ("GET",), **_options):
        def decorator(func):
            endpoint = f"{self.name}.{func.__name__}"
            self._routes.append((rule, endpoint, func, tuple(m.upper() for m in methods)))
            return func

        return decorator

    def get(self, rule: str, **options):
        return self.route(rule, methods=("GET",), **options)

    def post(self, rule: str, **options):
        return self.route(rule, methods=("POST",), **options)

    def put(self, rule: str, **options):
        return self.route(rule, methods=("PUT",), **options)

    def patch(self, rule: str, **options):
        return self.route(rule, methods=("PATCH",), **options)

    def delete(self, rule: str, **options):
        return self.route(rule, methods=("DELETE",), **options)

    # -- hooks ----------------------------------------------------------
    def errorhandler(self, exception: type[BaseException]):
        def decorator(func):
            self._error_handlers[exception] = func
            return func

        return decorator

    def app_template_filter(self, name: str | None = None):
        def decorator(func):
            from apps.core.templating import register_filter

            self._filters[name or func.__name__] = func
            register_filter(name or func.__name__, func)
            return func

        return decorator

    def app_template_global(self, name: str | None = None):
        def decorator(func):
            from apps.core.templating import register_global

            register_global(name or func.__name__, func)
            return func

        return decorator

    def before_app_request(self, func):
        self._before.append(func)
        return func

    def after_app_request(self, func):
        self._after.append(func)
        return func

    def app_context_processor(self, func):
        self._context_processors.append(func)
        return func

    # -- dispatch -------------------------------------------------------
    def handle(self, func: Callable, request, *args, **kwargs):
        return _dispatch(self, func, request, args, kwargs)

    def urlpatterns(self, prefix: str = ""):
        # Group routes that share the same rule so a single Django URL entry
        # can dispatch by HTTP method (Flask allows GET/POST on one path).
        grouped: dict[str, list] = {}
        for rule, endpoint, func, methods in self._routes:
            grouped.setdefault(rule, []).append((endpoint, func, methods))

        patterns = []
        for rule, entries in grouped.items():
            if len(entries) == 1:
                endpoint, func, methods = entries[0]
                view = _make_view(self, func, methods)
                patterns.append(django_path(to_django_rule(rule).lstrip("/"), view, name=endpoint))
                continue

            # Combine multiple handlers for the same path into one view that
            # dispatches based on the request method.
            def make_combined(entries):
                views_by_method = {}
                for endpoint, func, methods in entries:
                    v = _make_view(self, func, methods)
                    for m in methods:
                        views_by_method[m] = v
                # fallback to first
                fallback = _make_view(self, entries[0][1], entries[0][2])

                from django.views.decorators.csrf import csrf_exempt

                def combined(django_request, *args, **kwargs):
                    v = views_by_method.get(django_request.method, fallback)
                    return v(django_request, *args, **kwargs)

                combined.__name__ = "compat_combined"
                combined = csrf_exempt(combined)
                return combined

            combined_view = make_combined(entries)
            for endpoint, func, methods in entries:
                patterns.append(django_path(to_django_rule(rule).lstrip("/"), combined_view, name=endpoint))
        if prefix:
            return patterns
        return patterns
        return patterns

    def __repr__(self) -> str:  # pragma: no cover - debugging helper
        return f"<Blueprint {self.name!r} routes={len(self._routes)}>"


def _make_view(blueprint: Blueprint, func: Callable, methods: tuple[str, ...]):
    @csrf_exempt
    def view(django_request, *args, **kwargs):
        state = _STATE.get()
        if state is None or state["django_request"] is not django_request:
            bind_request(django_request)
        try:
            if django_request.method not in methods and not (
                django_request.method == "HEAD" and "GET" in methods
            ):
                return error_response(
                    django_request,
                    405,
                    f"طريقة الطلب {django_request.method} غير مسموح بها.",
                )
            result = func(*args, **kwargs)
            return to_response(result)
        except Exception as exc:  # noqa: BLE001 - mapped to HTTP responses below
            handled = _run_error_handlers(blueprint, exc)
            if handled is not None:
                return to_response(handled)
            return _exception_response(django_request, exc)
        finally:
            pass

    view.__name__ = f"compat_{blueprint.name}_{func.__name__}"
    view.__qualname__ = view.__name__
    return view


def _dispatch(blueprint: Blueprint, func: Callable, django_request, args, kwargs):
    state = _STATE.get()
    if state is None or state["django_request"] is not django_request:
        bind_request(django_request)
    return func(*args, **kwargs)


def _run_error_handlers(blueprint: Blueprint, exc: BaseException):
    for exception_class, handler in blueprint._error_handlers.items():
        if isinstance(exc, exception_class):
            return handler(exc)
    return None


def _exception_response(django_request, exc: BaseException):
    if isinstance(exc, HTTPError):
        return error_response(django_request, exc.code, exc.description)
    if isinstance(exc, Http404):
        return error_response(django_request, 404, _DEFAULT_ERRORS[404])
    from django.core.exceptions import PermissionDenied

    if isinstance(exc, PermissionDenied):
        return error_response(django_request, 403, _DEFAULT_ERRORS[403])
    from apps.core.utils import ValidationError

    if isinstance(exc, ValidationError):
        return error_response(django_request, 400, str(exc) or _DEFAULT_ERRORS[400])
    logger.exception("Unhandled error on %s", getattr(django_request, "path", "?"))
    return error_response(django_request, 500, _DEFAULT_ERRORS[500])


def urlpatterns_for(blueprint: Blueprint) -> list:
    """Return the Django ``urlpatterns`` entries for a blueprint."""
    return blueprint.urlpatterns()


# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------


def to_response(result: Any) -> HttpResponseBase:
    if isinstance(result, HttpResponseBase):
        return result
    if isinstance(result, tuple):
        if not result:
            return HttpResponse(b"")
        body = result[0]
        status = result[1] if len(result) > 1 else None
        headers = result[2] if len(result) > 2 else None
        response = to_response(body)
        if status is not None:
            response.status_code = int(status)
        if headers:
            for key, value in dict(headers).items():
                response[key] = value
        return response
    if result is None:
        return HttpResponse(b"")
    if isinstance(result, str):
        return HttpResponse(result, content_type="text/html; charset=utf-8")
    if isinstance(result, (dict, list)):
        return jsonify(result)
    if isinstance(result, bytes):
        return HttpResponse(result, content_type="application/octet-stream")
    return HttpResponse(str(result))


def jsonify(*args, **kwargs) -> FlaskResponse:
    if args and kwargs:
        raise TypeError("jsonify() behaviour undefined for positional and keyword arguments")
    if args:
        if len(args) > 1:
            payload: Any = list(args)
        else:
            payload = args[0]
    else:
        payload = kwargs
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    return FlaskResponse(body, mimetype="application/json")


def _content_disposition(attachment: bool, filename: str | None) -> str:
    try:
        from django.utils.http import content_disposition_header

        return content_disposition_header(attachment, filename) or ""
    except Exception:  # pragma: no cover - very old Django
        if filename:
            return f"{'attachment' if attachment else 'inline'}; filename*=UTF-8''{quote(filename)}"
        return "attachment" if attachment else "inline"


def send_file(
    path_or_file,
    mimetype: str | None = None,
    as_attachment: bool = False,
    download_name: str | None = None,
    conditional: bool = True,
    max_age: int | None = None,
    **_kwargs,
):
    if hasattr(path_or_file, "read"):
        data = path_or_file.read()
        if isinstance(data, str):
            data = data.encode("utf-8")
        response = FlaskResponse(data, content_type=mimetype or "application/octet-stream")
        if as_attachment or download_name:
            response["Content-Disposition"] = _content_disposition(as_attachment, download_name)
        if max_age is not None:
            response["Cache-Control"] = f"private, max-age={int(max_age)}"
        return response

    file_path = Path(path_or_file)
    if not file_path.is_file():
        raise Http404("File not found")
    if not mimetype:
        guess = None
        try:
            import mimetypes

            guess = mimetypes.guess_type(file_path.name)[0]
        except Exception:
            guess = None
        mimetype = guess or "application/octet-stream"
    response = FileResponse(
        open(file_path, "rb"),
        content_type=mimetype,
        as_attachment=as_attachment,
        filename=download_name or (file_path.name if as_attachment else None),
    )
    if max_age is not None:
        response["Cache-Control"] = f"public, max-age={int(max_age)}"
    return response


def send_from_directory(
    directory,
    path: str,
    conditional: bool = True,
    max_age: int | None = None,
    **_kwargs,
):
    base = Path(directory).resolve()
    target = (base / path).resolve()
    if base != target and base not in target.parents:
        raise Http404("File outside the allowed directory")
    if not target.is_file():
        raise Http404("File not found")
    return send_file(target, conditional=conditional, max_age=max_age)


def redirect(location: str, code: int = 302) -> HttpResponseRedirect:
    return HttpResponseRedirect(location, status=code)


def abort(code: int = 500, description: str | None = None):
    raise HTTPError(code, description)


def render_template(template_name: str, **context) -> HttpResponse:
    from apps.core.templating import render_compat_template

    return render_compat_template(template_name, context)


def _endpoint_params(endpoint: str) -> set[str]:
    """Return the converter names accepted by ``endpoint`` (if reverseable)."""
    try:
        from django.urls import get_resolver

        entries = get_resolver().reverse_dict.getlist(endpoint)
    except Exception:  # pragma: no cover - defensive
        return set()
    params: set[str] = set()
    for entry in entries:
        route = entry[0]
        converters = getattr(route, "_converters", None) or {}
        params.update(converters.keys())
    return params


def url_for(endpoint: str, **values) -> str:
    if endpoint == "static":
        filename = values.pop("filename", "")
        base = settings.STATIC_URL or "/static/"
        if not base.endswith("/"):
            base += "/"
        return base + quote(str(filename).replace("\\", "/"))

    external = values.pop("_external", False)
    anchor = values.pop("_anchor", None)
    values.pop("_method", None)
    values.pop("_scheme", None)

    # Flask accepts extra keyword arguments as query-string values.  Map only
    # the route converters to URL kwargs and send the rest through ``?``.
    params = _endpoint_params(endpoint)
    route_kwargs = {key: value for key, value in values.items() if key in params}
    extras = {key: value for key, value in values.items() if key not in params}
    try:
        url = reverse(endpoint, kwargs=route_kwargs)
    except NoReverseMatch:
        logger.warning("url_for could not reverse endpoint %r (%s)", endpoint, values)
        return "/"
    if extras:
        from urllib.parse import urlencode

        url = f"{url}?{urlencode(extras)}"
    if anchor:
        url = f"{url}#{anchor}"
    if external:
        try:
            from django.contrib.sites.shortcuts import get_current_site

            site = get_current_site(current_django_request() if _STATE.get() else None)
            url = f"http://{site.domain}{url}"
        except Exception:
            pass
    return url


def error_response(django_request, status: int, message: str | None = None) -> HttpResponse:
    from apps.core.errors import error_response as _error_response

    return _error_response(django_request, status, message)


__all__ = [
    "Blueprint",
    "HTTPError",
    "Response",
    "abort",
    "bind_request",
    "current_app",
    "error_response",
    "g",
    "get_app",
    "jsonify",
    "redirect",
    "render_template",
    "request",
    "send_file",
    "send_from_directory",
    "session",
    "to_response",
    "unbind_request",
    "url_for",
    "urlpatterns_for",
]

Response = FlaskResponse
