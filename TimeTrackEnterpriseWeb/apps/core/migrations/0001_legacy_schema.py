"""Create the legacy-compatible SQLite schema.

Django owns the ORM tables through the other migrations; the functional
modules keep using their hand-written SQL against the same SQLite file.  This
data migration creates those tables (idempotently) so a fresh checkout, a test
database and the desktop build all share the same schema.
"""
from __future__ import annotations

from django.db import migrations


def create_legacy_schema(apps, schema_editor):
    connection = schema_editor.connection
    if connection.vendor != "sqlite":
        # The compatibility layer is SQLite-only today; see
        # docs/reviews/synchronization.md for the tracked follow-up work.
        return
    from apps.core.db import SCHEMA_VERSION, apply_schema, seed_database

    with connection.cursor() as cursor:
        apply_schema(cursor)
        seed_database(cursor)
        cursor.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")


def drop_legacy_schema(apps, schema_editor):
    connection = schema_editor.connection
    if connection.vendor != "sqlite":
        return
    tables = (
        "message_outbox",
        "message_campaigns",
        "exit_slips",
        "entry_slips",
        "period_closures",
        "sms_logs",
        "attendance_logs",
        "periods",
        "students",
        "users",
        "settings",
        "app_meta",
    )
    with connection.cursor() as cursor:
        for table in tables:
            cursor.execute(f"DROP TABLE IF EXISTS {table}")


class Migration(migrations.Migration):
    initial = True

    dependencies: list[tuple[str, str]] = []

    operations = [
        # The reverse is intentionally a no-op: dropping ``users`` would break
        # Django's swappable user model and lose application data.
        migrations.RunPython(create_legacy_schema, migrations.RunPython.noop),
    ]
