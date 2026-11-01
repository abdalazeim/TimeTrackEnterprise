"""Initial ORM schema for the core app.

Only the tables owned by Django are created here.  The legacy-compatible
tables (``users``, ``students``, ``attendance_logs`` ...) are created by
``core.0001_legacy_schema`` because the functional layer keeps its raw SQL
access and must not be managed by Django.
"""
from __future__ import annotations

from datetime import datetime

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        ("core", "0001_legacy_schema"),
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="AuditLog",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                ("created_at", models.DateTimeField(db_index=True, default=datetime.now)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "action",
                    models.CharField(
                        choices=[
                            ("create", "create"),
                            ("update", "update"),
                            ("delete", "delete"),
                            ("login", "login"),
                            ("logout", "logout"),
                            ("backup", "backup"),
                            ("shutdown", "shutdown"),
                            ("import", "import"),
                            ("close_period", "close_period"),
                            ("excuse", "excuse"),
                            ("issue_slip", "issue_slip"),
                            ("send_sms", "send_sms"),
                            ("update_check", "update_check"),
                            ("update_install", "update_install"),
                        ],
                        db_index=True,
                        max_length=32,
                    ),
                ),
                ("target_table", models.CharField(blank=True, db_index=True, max_length=64)),
                ("target_id", models.CharField(blank=True, db_index=True, max_length=64)),
                ("ip_address", models.GenericIPAddressField(blank=True, null=True)),
                ("user_agent", models.CharField(blank=True, max_length=255)),
                ("detail", models.JSONField(blank=True, default=dict)),
                (
                    "user",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="audit_logs",
                        to="accounts.user",
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="SystemSetting",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                ("created_at", models.DateTimeField(db_index=True, default=datetime.now)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("key", models.CharField(db_index=True, max_length=64, unique=True)),
                ("value", models.TextField(blank=True, default="")),
            ],
            options={
                "ordering": ["key"],
            },
        ),
        migrations.CreateModel(
            name="LookupCategory",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                ("created_at", models.DateTimeField(db_index=True, default=datetime.now)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=80, unique=True)),
                ("items", models.JSONField(blank=True, default=list)),
            ],
            options={
                "ordering": ["name"],
            },
        ),
        migrations.AddIndex(
            model_name="auditlog",
            index=models.Index(
                fields=["action", "created_at"], name="core_auditl_action_6b3f5a_idx"
            ),
        ),
        migrations.AddIndex(
            model_name="auditlog",
            index=models.Index(
                fields=["target_table", "target_id"], name="core_auditl_target__36e1a2_idx"
            ),
        ),
    ]
