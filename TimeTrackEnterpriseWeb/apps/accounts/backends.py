"""Authentication backend for legacy Werkzeug password hashes."""
from __future__ import annotations

from django.contrib.auth.backends import BaseBackend

from apps.accounts.models import User
from apps.accounts.services import verify_password


class LegacyBackend(BaseBackend):
    """Authenticate against the ``users`` table of the legacy schema.

    Passwords created by the Flask application are Werkzeug PBKDF2 hashes;
    a NULL hash means "no password" (first-run administrator).
    """

    def authenticate(self, request, username=None, password=None, **kwargs):
        if username is None:
            username = kwargs.get(User.USERNAME_FIELD)
        if not username:
            return None
        try:
            user = User.objects.get(username__iexact=str(username).strip())
        except User.DoesNotExist:
            return None
        except Exception:  # pragma: no cover - database not ready
            return None
        if not user.is_active:
            return None
        if password is None:
            password = ""
        return user if verify_password(user.password, password) else None

    def get_user(self, user_id):
        try:
            return User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return None
        except Exception:  # pragma: no cover - database not ready
            return None

    def has_perm(self, user_obj, perm, obj=None) -> bool:
        return bool(user_obj and user_obj.is_active and user_obj.has_perm(perm, obj))

    def has_module_perms(self, user_obj, app_label) -> bool:
        return bool(user_obj and user_obj.is_active and user_obj.has_module_perms(app_label))
