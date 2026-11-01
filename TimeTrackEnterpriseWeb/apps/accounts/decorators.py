"""Access-control decorators for the migrated views."""
from __future__ import annotations

from functools import wraps

from apps.core.compat import g, jsonify, render_template, request


def admin_required(view):
    """Require an active administrator, mirroring the Flask decorator."""

    @wraps(view)
    def wrapped(*args, **kwargs):
        user = g.get("user")
        if not user or user.get("role") != "admin":
            if request.path.startswith("/api/"):
                return (
                    jsonify(
                        ok=False,
                        error={
                            "code": "forbidden",
                            "message": "ليست لديك صلاحية الوصول إلى هذه العملية.",
                        },
                    ),
                    403,
                )
            return (
                render_template(
                    "error.html",
                    code=403,
                    message="ليست لديك صلاحية الوصول إلى هذه الصفحة. ارجع إلى مدير النظام.",
                ),
                403,
            )
        return view(*args, **kwargs)

    return wrapped


def login_required_json(view):
    """Require a session user for a JSON endpoint."""

    @wraps(view)
    def wrapped(*args, **kwargs):
        user = g.get("user")
        if not user:
            return (
                jsonify(
                    ok=False,
                    error={"code": "auth_required", "message": "يجب تسجيل الدخول للمتابعة."},
                ),
                401,
            )
        return view(*args, **kwargs)

    return wrapped
