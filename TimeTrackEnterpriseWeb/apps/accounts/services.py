"""Account services.

These functions keep the public contract of the legacy Flask module
(``dict`` records, Arabic validation messages, Werkzeug password hashes)
while operating on the shared SQLite database through the compatibility
layer.  The Django auth backend uses the same helpers.
"""
from __future__ import annotations

import hmac
import re
import secrets
from datetime import datetime

from werkzeug.security import check_password_hash, generate_password_hash

from apps.core.compat import g, request, session
from apps.core.config import ROLE_LABELS
from apps.core.db import get_db

USERNAME_RE = re.compile(r"^[A-Za-z0-9_.-]{3,32}$")
ROLES = {"admin", "user"}
PASSWORD_MIN = 6
PASSWORD_MAX = 128


class AccountError(ValueError):
    """Raised for user-facing account validation errors."""


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


# ---------------------------------------------------------------------------
# Reads
# ---------------------------------------------------------------------------
def get_user(user_id: int | None) -> dict | None:
    if not user_id:
        return None
    row = get_db().execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return dict(row) if row else None


def get_user_by_username(username: str) -> dict | None:
    row = get_db().execute(
        "SELECT * FROM users WHERE username = ? COLLATE NOCASE", (username,)
    ).fetchone()
    return dict(row) if row else None


def public_user(row: dict) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "display_name": row["display_name"],
        "role": row["role"],
        "role_label": ROLE_LABELS.get(row["role"], row["role"]),
        "is_active": bool(row["is_active"]),
        "has_password": bool(row["password_hash"]),
        "created_at": row["created_at"],
        "last_login_at": row["last_login_at"],
    }


def list_users() -> list[dict]:
    rows = get_db().execute(
        "SELECT * FROM users ORDER BY CASE role WHEN 'admin' THEN 0 ELSE 1 END, username"
    ).fetchall()
    return [public_user(dict(row)) for row in rows]


# ---------------------------------------------------------------------------
# Validation and password hashing
# ---------------------------------------------------------------------------
def _normalize_username(value: str) -> str:
    username = (value or "").strip()
    if not USERNAME_RE.fullmatch(username):
        raise AccountError("اسم المستخدم يجب أن يكون بين 3 و32 حرفًا لاتينيًا أو رقمًا أو . _ -")
    return username


def _normalize_display_name(value: str, username: str) -> str:
    display_name = (value or "").strip() or username
    if len(display_name) > 80:
        raise AccountError("الاسم المعروض أطول من 80 حرفًا.")
    return display_name


def _normalize_role(value: str) -> str:
    role = (value or "user").strip().lower()
    if role not in ROLES:
        raise AccountError("الدور المحدد غير صالح.")
    return role


def _normalize_password(password: str | None) -> str | None:
    value = password or ""
    if not value:
        return None
    if len(value) < PASSWORD_MIN:
        raise AccountError(f"كلمة المرور يجب ألا تقل عن {PASSWORD_MIN} أحرف.")
    if len(value) > PASSWORD_MAX:
        raise AccountError(f"كلمة المرور أطول من {PASSWORD_MAX} حرفًا.")
    return value


def hash_password(password: str) -> str:
    return generate_password_hash(password)


def verify_password(stored_hash: str | None, password: str | None) -> bool:
    """Verify a legacy Werkzeug hash; a NULL hash means "no password"."""
    if stored_hash:
        try:
            return check_password_hash(stored_hash, password or "")
        except (ValueError, TypeError):
            return False
    return (password or "") == ""


def _active_admins(conn, excluding: int | None = None) -> int:
    sql = "SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1"
    params: tuple = ()
    if excluding is not None:
        sql += " AND id <> ?"
        params = (excluding,)
    return conn.execute(sql, params).fetchone()[0]


# ---------------------------------------------------------------------------
# Writes
# ---------------------------------------------------------------------------
def create_user(
    username: str,
    display_name: str,
    role: str,
    password: str | None = None,
    is_active: bool = True,
) -> dict:
    conn = get_db()
    username = _normalize_username(username)
    display_name = _normalize_display_name(display_name, username)
    role = _normalize_role(role)
    password = _normalize_password(password)
    now = _now()
    try:
        with conn:
            cursor = conn.execute(
                """INSERT INTO users(username, display_name, role, password_hash, is_active,
                                     created_at, updated_at, last_login_at)
                   VALUES(?, ?, ?, ?, ?, ?, ?, NULL)""",
                (
                    username,
                    display_name,
                    role,
                    hash_password(password) if password else None,
                    1 if is_active else 0,
                    now,
                    now,
                ),
            )
    except Exception as error:  # noqa: BLE001 - normalise UNIQUE errors
        if "UNIQUE" in str(error).upper():
            raise AccountError("اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.") from error
        raise
    row = conn.execute("SELECT * FROM users WHERE id = ?", (cursor.lastrowid,)).fetchone()
    return public_user(dict(row))


def update_user(
    user_id: int,
    display_name: str,
    role: str,
    password: str | None = None,
    clear_password: bool = False,
    is_active: bool = True,
    acting_user_id: int | None = None,
) -> dict:
    conn = get_db()
    current = get_user(user_id)
    if not current:
        raise AccountError("المستخدم غير موجود.")
    role = _normalize_role(role)
    display_name = _normalize_display_name(display_name, current["username"])
    password = _normalize_password(password)
    if acting_user_id == user_id and (role != "admin" or not is_active):
        raise AccountError("لا يمكنك إزالة صلاحية مدير النظام عن حسابك أو تعطيله.")
    losing_admin = (
        current["role"] == "admin"
        and current["is_active"]
        and (role != "admin" or not is_active)
    )
    if losing_admin and _active_admins(conn, excluding=user_id) == 0:
        raise AccountError("يجب أن يبقى مدير نظام واحد نشط على الأقل.")

    password_hash = current["password_hash"]
    if clear_password:
        password_hash = None
    elif password:
        password_hash = hash_password(password)

    with conn:
        conn.execute(
            """UPDATE users
               SET display_name = ?, role = ?, password_hash = ?, is_active = ?,
                   updated_at = ?
               WHERE id = ?""",
            (
                display_name,
                role,
                password_hash,
                1 if is_active else 0,
                _now(),
                user_id,
            ),
        )
    return public_user(get_user(user_id))


def delete_user(user_id: int, acting_user_id: int) -> None:
    conn = get_db()
    current = get_user(user_id)
    if not current:
        raise AccountError("المستخدم غير موجود.")
    if user_id == acting_user_id:
        raise AccountError("لا يمكنك حذف حسابك الحالي.")
    if current["role"] == "admin" and current["is_active"] and _active_admins(conn, excluding=user_id) == 0:
        raise AccountError("يجب أن يبقى مدير نظام واحد نشط على الأقل.")
    with conn:
        conn.execute("DELETE FROM users WHERE id = ?", (user_id,))


def set_user_password(user_id: int, password: str | None) -> None:
    conn = get_db()
    value = _normalize_password(password)
    with conn:
        conn.execute(
            "UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?",
            (hash_password(value) if value else None, _now(), user_id),
        )


def touch_login(user_id: int) -> None:
    now = _now()
    conn = get_db()
    with conn:
        conn.execute(
            "UPDATE users SET last_login_at = ?, updated_at = ? WHERE id = ?",
            (now, now, user_id),
        )


# ---------------------------------------------------------------------------
# Session / CSRF helpers
# ---------------------------------------------------------------------------
def ensure_csrf_token() -> str:
    token = session.get("csrf_token")
    if not token:
        token = secrets.token_urlsafe(32)
        session["csrf_token"] = token
    return token


def check_csrf() -> bool:
    sent = request.form.get("csrf_token") or request.headers.get("X-CSRF-Token")
    stored = session.get("csrf_token")
    return bool(sent and stored and hmac.compare_digest(str(sent), str(stored)))


def rotate_csrf_token() -> str:
    token = secrets.token_urlsafe(32)
    session["csrf_token"] = token
    return token


def current_user() -> dict | None:
    try:
        return g.get("user")
    except Exception:
        return None


def safe_next(value: str | None, fallback: str = "/") -> str:
    from urllib.parse import urlsplit

    candidate = (value or "").strip()
    if not candidate or "\\" in candidate or any(ord(ch) < 32 for ch in candidate):
        return fallback
    if not candidate.startswith("/") or candidate.startswith("//"):
        return fallback
    parsed = urlsplit(candidate)
    if parsed.scheme or parsed.netloc:
        return fallback
    return candidate
