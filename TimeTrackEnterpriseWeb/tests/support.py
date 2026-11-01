"""Test support: a Flask-style client on top of ``django.test.Client``.

The functional tests were written against the legacy Flask application.  They
use ``client.get(..., query_string=...)``, ``client.post(..., json=...)``,
``response.get_json()``, ``client.session_transaction()`` and a handful of
other Flask conveniences.  Rewriting every assertion would add no value, so
this module provides a thin adapter that keeps the tests readable while the
requests themselves go through the real Django stack (middleware, sessions,
URL routing and the compatibility views).
"""
from __future__ import annotations

import json as jsonlib
from contextlib import contextmanager
from urllib.parse import urlencode

from django.test import Client

from apps.core.compat import get_app


class CompatResponse:
    """Flask-like response wrapper around a Django response object."""

    def __init__(self, response) -> None:
        self._response = response

    # -- Flask API ------------------------------------------------------
    @property
    def status_code(self) -> int:
        return self._response.status_code

    @property
    def headers(self):
        return self._response.headers

    @property
    def data(self) -> bytes:
        return self._response.content

    @property
    def content_type(self) -> str:
        return self._response.headers.get("Content-Type", "")

    @property
    def mimetype(self) -> str:
        return (self.content_type or "").split(";", 1)[0].strip()

    @property
    def text(self) -> str:
        return self.get_data(as_text=True)

    def get_data(self, as_text: bool = False):
        body = self._response.content
        if not as_text:
            return body
        charset = getattr(self._response, "charset", None) or "utf-8"
        return body.decode(charset, "replace")

    def get_json(self, **_kwargs):
        return jsonlib.loads(self._response.content.decode("utf-8"))

    def __getattr__(self, name):
        return getattr(self._response, name)


class CompatClient:
    """Flask-style test client backed by ``django.test.Client``."""

    def __init__(self, django_client: Client | None = None) -> None:
        self._client = django_client or Client()

    # -- cookie / session helpers --------------------------------------
    def set_cookie(self, key, value="", **kwargs):
        self._client.set_cookie(key, value, **kwargs)

    def delete_cookie(self, key, **kwargs):
        self._client.delete_cookie(key, **kwargs)

    @property
    def cookies(self):
        return self._client.cookies

    @contextmanager
    def session_transaction(self):
        session = self._client.session
        yield session
        session.save()

    # -- requests -------------------------------------------------------
    def _request(
        self,
        method: str,
        path: str,
        *,
        query_string=None,
        json=None,
        data=None,
        headers=None,
        content_type=None,
        follow_redirects: bool = False,
        **extra,
    ) -> CompatResponse:
        if query_string:
            query = urlencode(query_string, doseq=True)
            path = f"{path}{'&' if '?' in path else '?'}{query}"

        kwargs = {}
        if headers:
            kwargs["headers"] = headers
        kwargs.update(extra)

        if json is not None:
            data = jsonlib.dumps(json, ensure_ascii=False)
            content_type = "application/json"
        if content_type:
            kwargs["content_type"] = content_type

        request = getattr(self._client, method)
        response = request(path, data=data, follow=follow_redirects, **kwargs)
        return CompatResponse(response)

    def get(self, path, **kwargs):
        return self._request("get", path, **kwargs)

    def post(self, path, **kwargs):
        return self._request("post", path, **kwargs)

    def put(self, path, **kwargs):
        return self._request("put", path, **kwargs)

    def patch(self, path, **kwargs):
        return self._request("patch", path, **kwargs)

    def delete(self, path, **kwargs):
        return self._request("delete", path, **kwargs)

    def head(self, path, **kwargs):
        return self._request("head", path, **kwargs)

    def options(self, path, **kwargs):
        return self._request("options", path, **kwargs)


class CompatTestApp:
    """Minimal stand-in for the former Flask ``app`` fixture."""

    def __init__(self) -> None:
        self._app = get_app()

    @property
    def config(self) -> dict:
        self._app.refresh()
        return self._app.config

    @property
    def extensions(self) -> dict:
        return self._app.extensions

    def app_context(self):
        return self._app.app_context()

    def test_client(self) -> CompatClient:
        return CompatClient()

    def __getattr__(self, name):
        return getattr(self._app, name)


__all__ = ["CompatClient", "CompatResponse", "CompatTestApp"]
