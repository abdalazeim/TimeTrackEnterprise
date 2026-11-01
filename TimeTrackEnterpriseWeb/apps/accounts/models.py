"""Accounts models.

The ``users`` table is owned by the legacy-compatible schema (see
``apps.core.db.SCHEMA``) and is mapped here without Django managing its
creation.  This lets the Django authentication framework (sessions,
``request.user``, the admin) and the migrated functional layer share the
exact same rows.
"""
from __future__ import annotations

from django.contrib.auth.base_user import AbstractBaseUser
from django.db import models


class User(AbstractBaseUser):
    """Legacy ``users`` row exposed as a Django user model."""

    ROLES = (("admin", "مدير النظام"), ("user", "مستخدم"))

    id = models.AutoField(primary_key=True)
    username = models.CharField("اسم المستخدم", max_length=32, unique=True)
    display_name = models.CharField("الاسم المعروض", max_length=80, blank=True, default="")
    role = models.CharField("الدور", max_length=16, choices=ROLES, default="user")
    password = models.CharField(
        "كلمة المرور", max_length=255, null=True, blank=True, db_column="password_hash"
    )
    is_active = models.BooleanField("نشط", default=True)
    created_at = models.CharField(max_length=32, blank=True, default="")
    updated_at = models.CharField(max_length=32, blank=True, default="")
    last_login = models.DateTimeField(null=True, blank=True, db_column="last_login_at")

    USERNAME_FIELD = "username"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        managed = False
        db_table = "users"
        verbose_name = "مستخدم"
        verbose_name_plural = "المستخدمون"
        ordering = ("username",)

    def __str__(self) -> str:
        return self.display_name or self.username

    # -- profile helpers -------------------------------------------------
    def get_full_name(self) -> str:
        return self.display_name or self.username

    def get_short_name(self) -> str:
        return self.display_name or self.username

    @property
    def role_label(self) -> str:
        return dict(self.ROLES).get(self.role, self.role)

    @property
    def is_admin(self) -> bool:
        return self.role == "admin"

    # -- Django admin / auth contract ------------------------------------
    @property
    def is_staff(self) -> bool:
        return self.role == "admin"

    @property
    def is_superuser(self) -> bool:
        return self.role == "admin"

    @property
    def is_anonymous(self) -> bool:
        return False

    @property
    def is_authenticated(self) -> bool:
        return True

    def has_perm(self, perm, obj=None) -> bool:
        if self.role == "admin":
            return True
        from apps.core.constants import ROLE_PERMISSIONS

        return perm in ROLE_PERMISSIONS.get(self.role, [])

    def has_perms(self, perm_list, obj=None) -> bool:
        return all(self.has_perm(perm, obj) for perm in perm_list)

    def has_module_perms(self, app_label: str) -> bool:
        if self.role == "admin":
            return True
        from apps.core.constants import ROLE_PERMISSIONS

        return any(perm.startswith(f"{app_label}.") for perm in ROLE_PERMISSIONS.get(self.role, []))

    def get_all_permissions(self, obj=None) -> set[str]:
        from apps.core.constants import PERMISSION_CODES, ROLE_PERMISSIONS

        if self.role == "admin":
            return set(PERMISSION_CODES)
        return set(ROLE_PERMISSIONS.get(self.role, []))

    def get_user_permissions(self, obj=None) -> set[str]:
        return self.get_all_permissions(obj)

    def get_group_permissions(self, obj=None) -> set[str]:
        return set()
