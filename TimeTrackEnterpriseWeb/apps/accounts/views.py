"""Login, logout and session views."""
from __future__ import annotations

import time

from apps.accounts.decorators import login_required_json
from apps.accounts.services import (
    check_csrf,
    get_user,
    get_user_by_username,
    rotate_csrf_token,
    safe_next,
    touch_login,
    verify_password,
)
from apps.core.compat import Blueprint, g, jsonify, redirect, render_template, request, session, url_for
from apps.core.db import get_db, get_settings

auth_bp = Blueprint("auth", __name__)

_ATTEMPT_WINDOW = 300
_ATTEMPT_LIMIT = 5
_ATTEMPTS: dict[str, list[float]] = {}


def _attempt_key(username: str) -> str:
    return f"{(username or '').strip().lower()}|{request.remote_addr or 'local'}"


def _attempt_remaining(key: str) -> int:
    now = time.time()
    attempts = [stamp for stamp in _ATTEMPTS.get(key, []) if now - stamp < _ATTEMPT_WINDOW]
    _ATTEMPTS[key] = attempts
    if len(attempts) < _ATTEMPT_LIMIT:
        return 0
    return max(1, int(_ATTEMPT_WINDOW - (now - attempts[0])))


def _record_failure(key: str) -> None:
    _ATTEMPTS.setdefault(key, []).append(time.time())


def _clear_failures(key: str) -> None:
    _ATTEMPTS.pop(key, None)


def _login_context(error: str = "", status: int = 200, username: str = "", next_url: str = ""):
    settings = get_settings(get_db())
    open_admin = get_db().execute(
        "SELECT 1 FROM users WHERE role = 'admin' AND is_active = 1 AND password_hash IS NULL LIMIT 1"
    ).fetchone()
    return (
        render_template(
            "login.html",
            error=error,
            username=username,
            next_url=next_url,
            school_name=settings.get("school_name", ""),
            logo_path=settings.get("logo_path", ""),
            academic_year=settings.get("academic_year", ""),
            open_admin=bool(open_admin),
        ),
        status,
    )


@auth_bp.get("/login")
def login_page():
    next_url = safe_next(request.args.get("next"), "/")
    user = get_user(session.get("user_id"))
    if user and user["is_active"]:
        return redirect(next_url)
    return _login_context(next_url=next_url)


@auth_bp.post("/login")
def login_submit():
    next_url = safe_next(request.form.get("next"), "/")
    username = str(request.form.get("username") or "").strip()
    password = str(request.form.get("password") or "")
    if not check_csrf():
        return _login_context(
            "انتهت صلاحية الجلسة. أعد تحميل الصفحة ثم حاول مجددًا.", 400, username, next_url
        )

    key = _attempt_key(username)
    remaining = _attempt_remaining(key)
    if remaining:
        return _login_context(
            f"محاولات دخول كثيرة. انتظر {remaining} ثانية ثم حاول مجددًا.",
            429,
            username,
            next_url,
        )

    user = get_user_by_username(username)
    valid = bool(user and user["is_active"] and verify_password(user["password_hash"], password))
    if not valid:
        _record_failure(key)
        return _login_context("اسم المستخدم أو كلمة المرور غير صحيحة.", 401, username, next_url)

    _clear_failures(key)
    session.clear()
    session.permanent = True
    session["user_id"] = user["id"]
    rotate_csrf_token()
    touch_login(user["id"])
    return redirect(next_url)


@auth_bp.post("/logout")
def logout():
    if not check_csrf():
        return redirect(url_for("auth.login_page"))
    session.clear()
    return redirect(url_for("auth.login_page"))


# ---------------------------------------------------------------------------
# JSON endpoint (Django-native) exposing the current session identity
# ---------------------------------------------------------------------------
@login_required_json
def session_me(_request):
    from django.http import JsonResponse

    user = g.get("user") or {}
    return JsonResponse(
        {
            "ok": True,
            "user": {
                "id": user.get("id"),
                "username": user.get("username"),
                "display_name": user.get("display_name"),
                "role": user.get("role"),
                "is_active": bool(user.get("is_active")),
            },
        },
        json_dumps_params={"ensure_ascii": False},
    )
