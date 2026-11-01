# Database

The application uses **SQLite** at `DB_PATH` (`DATA_DIR/attendance.db` by
default). Django and the migrated functional layer share the same file, so a
backup is a single file copy.

## Layout

### Legacy tables (hand-written schema)

Created by `apps/core/db.py::SCHEMA` (`SCHEMA_VERSION = 5`) through
`ensure_database()` and the idempotent migration
`apps/core/migrations/0001_legacy_schema.py`.

| Table | Contents |
| --- | --- |
| `app_meta` | schema/installation markers (`initialized_at`) |
| `settings` | key/value application settings (`DEFAULT_SETTINGS`) |
| `users` | accounts (username, role, Werkzeug PBKDF2 hash, active flag) |
| `students` | student records, unique `student_nin` |
| `periods` | school periods and cut-off times |
| `attendance_logs` | one row per `(student, period, date)`, status PRESENT/LATE/ABSENT/EXCUSED |
| `sms_logs` | outbox/history per attendance row, gateway and attempt counters |
| `period_closures` | closed periods (prevents double closure) |
| `entry_slips` / `exit_slips` | signed slips, QR payloads, print/return timestamps |
| `message_campaigns` | bulk messaging campaigns and counters |
| `message_outbox` | per-recipient campaign items |

Foreign keys: logs/slips reference `students(student_nin)` and `periods(id)`;
`message_outbox` cascades from `message_campaigns`. SQLite foreign keys are
enabled on every connection (`PRAGMA foreign_keys = ON`).

### Django tables

| Table | Contents |
| --- | --- |
| `django_migrations`, `django_content_type`, `auth_permission` | framework |
| `django_session` | browser sessions (`user_id`, `csrf_token`) |
| `django_admin_log` | administrator actions |
| `sync_devices` | paired clients (UUID, token, platform, last seen) |
| `sync_records` | idempotent pushed changes (`client_id` unique, revisions) |
| `sync_conflicts` | conflicts awaiting review and their resolution |

## `accounts.User`

`apps/accounts/models.py` maps the legacy table instead of owning it:

```python
class User(models.Model):
    class Meta:
        managed = False
        db_table = "users"
```

Properties expose `is_staff`/`is_superuser` (role == "admin") and `is_authenticated`
so Django admin and `AuthenticationMiddleware` work without adding columns.
`apps/accounts/backends.py::LegacyBackend` verifies the Werkzeug PBKDF2 hash and
returns the same dictionary shape as the services (`get_user()`).

## Revisions and conflicts

`SyncRecord.server_revision` is a per-`(entity, entity_key)` counter starting
at 1. Push rules:

* `client_id` already present → return the stored record (`duplicate`).
* `operation=create` for a key that already has a record → conflict.
* `base_revision` lower than the latest applied revision → conflict.
* otherwise → `applied`, and any older pending conflict for the key is
  auto-resolved to `server`.

Resolving a conflict (`local`/`merged`) bumps the revision; `server` marks the
client record `rejected`. `pull` only returns `applied` records from other
devices.

## Initialisation

1. `CoreConfig.ready()` → `ensure_database()` → `init_db(DB_PATH)`.
2. `init_db` enables WAL, applies `SCHEMA`, sets `PRAGMA user_version`, seeds
   `DEFAULT_SETTINGS`, the passwordless `admin` account (if no users exist) and
   the default morning period.
3. `manage.py migrate` creates the Django tables (and repeats the legacy step).

`seed_database()` is safe to run repeatedly: it uses `ON CONFLICT DO NOTHING`
and only inserts the administrator/periods when the tables are empty.

## Backups and restore

* UI: **الإعدادات → نسخة احتياطية** or `GET /api/system/backup` (admin) →
  gzipped copy via `apps/core/services/backup.py`.
* CLI: `python scripts/backup.py` writes to `backups/`.
* Restore: stop the application, replace `data/attendance.db` with the backup
  (decompress if `.gz`), start again. Keep `data/photos`, `data/uploads` and
  `data/updates` next to the database.
* The sync tables are part of the same file; a restore also restores device
  tokens — revoke unexpected devices afterwards from the admin.

## Migrations

```powershell
python manage.py makemigrations          # after changing a managed model
python manage.py migrate                 # apply
python manage.py showmigrations
python manage.py sqlmigrate accounts 0001
```

Never edit the legacy `users` table with a managed migration; change the
hand-written schema in `apps/core/db.py` and add an idempotent migration.
