"""Custom user model backed by the legacy ``users`` table.

The table is created by :mod:`apps.core.db` (and by the ``core`` data
migration); ``managed = False`` keeps Django from trying to create or alter
it.  The migration still exists because ``django.contrib.admin`` references
``settings.AUTH_USER_MODEL`` through ``swappable_dependency``.
"""
from __future__ import annotations

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies: list[tuple[str, str]] = []

    operations = [
        migrations.CreateModel(
            name="User",
            fields=[
                ("id", models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("username", models.CharField(max_length=32, unique=True, verbose_name="اسم المستخدم")),
                ("display_name", models.CharField(blank=True, default="", max_length=80, verbose_name="الاسم المعروض")),
                (
                    "role",
                    models.CharField(
                        choices=[("admin", "مدير النظام"), ("user", "مستخدم")],
                        default="user",
                        max_length=16,
                        verbose_name="الدور",
                    ),
                ),
                (
                    "password",
                    models.CharField(
                        blank=True,
                        db_column="password_hash",
                        max_length=255,
                        null=True,
                        verbose_name="كلمة المرور",
                    ),
                ),
                ("is_active", models.BooleanField(default=True, verbose_name="نشط")),
                ("created_at", models.CharField(blank=True, default="", max_length=32)),
                ("updated_at", models.CharField(blank=True, default="", max_length=32)),
                (
                    "last_login",
                    models.DateTimeField(blank=True, db_column="last_login_at", null=True),
                ),
            ],
            options={
                "verbose_name": "مستخدم",
                "verbose_name_plural": "المستخدمون",
                "db_table": "users",
                "managed": False,
                "ordering": ("username",),
            },
        ),
    ]
