# Architecture

TimeTrack Enterprise is a Django 5 application whose functional core was
migrated from a Flask codebase. Business logic was kept as close to the
original as practical; the framework plumbing was replaced by a small
compatibility layer so the migration could be verified function by function.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Browser / Android client / desktop launcher                          │
└───────────────┬──────────────────────────────────────────────────────┘
                │ HTTP
┌───────────────▼──────────────────────────────────────────────────────┐
│ config/            settings, URLconf, WSGI/ASGI, desktop hardening   │
├──────────────────────────────────────────────────────────────────────┤
│ apps/core          compat bridge, SQLite layer, i18n, templating,    │
│                    middleware, health, backups, static serving       │
│ apps/accounts      login/session, roles, AccountGateMiddleware       │
│ apps/synchronization  devices, idempotent push/pull, conflicts       │
│ apps/modules       pages + ~75 legacy JSON endpoints + services      │
└───────────────┬──────────────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────────────┐
│ SQLite (DATA_DIR/TimeTrackEnterprise.db)                              │
│   legacy tables (users, students, periods, logs, slips, messages…)   │
│   Django tables (sessions, admin, sync_records, sync_conflicts…)     │
└──────────────────────────────────────────────────────────────────────┘
```

## Request lifecycle

1. `SecurityMiddleware` and `SessionMiddleware` run first.
2. `apps.core.middleware.compat.CompatRequestMiddleware` binds the
   Flask-compatible `request` / `g` / `session` / `current_app` proxies, sets
   the interface language from the `attendance_lang` cookie, loads the session
   user into `g.user`, and closes the per-thread SQLite connection after the
   response.
3. `AccountGateMiddleware` enforces login, administrator-only prefixes and the
   `X-Requested-With: StudentAttendance` guard. `/api/sync/` requests carrying
   `X-Device-Token` bypass the session gate.
4. The view runs. Migrated views are registered on a `Blueprint`; `config`
   converts Flask rules (`<int:id>`, `<path:code>`) into Django `path()`
   patterns (`apps/core/compat.py::urlpatterns_for`).
5. `CompatRequestMiddleware` localises the response (Arabic → English/French),
   normalises digits, and adds CSP, `X-Frame-Options`, `X-Content-Type-Options`
   and `Referrer-Policy`.

## The compatibility layer

`apps/core/compat.py` implements only what the migrated modules actually use:

| Flask | Replacement |
| --- | --- |
| `Blueprint` + route decorators | Django `path()` patterns, `csrf_exempt` |
| `request`, `g`, `session` | ContextVar-bound proxies over `HttpRequest` |
| `current_app.config` | `CompatApp` view of Django settings |
| `jsonify`, `Response` | `FlaskResponse` (`mimetype=` accepted) |
| `send_file`, `send_from_directory` | `FileResponse` with traversal checks |
| `render_template` | Jinja2 backend through `apps/core/templating.py` |
| `url_for` | `django.urls.reverse`, route converters + query extras |
| `abort`, `HTTPError` | JSON/HTML error response helpers |

The proxies are request-scoped: `bind_request()` is called by middleware (and
by the blueprint view wrapper for direct calls). Nothing depends on Flask.

## Templates and static files

* `config/jinja2.py` configures Jinja2 and a `LayoutLoader` that resolves the
  flat legacy names (`dashboard.html`) to the new folders (`pages/dashboard.html`,
  `base/…`, `partials/…`, `print/…`).
* `DjangoTemplates` is listed **first** in `TEMPLATES` so `django.contrib.admin`
  templates are never parsed by Jinja2.
* Rendering goes through `backend_template.template.render(context)`;
  `base_context()` supplies the globals that Flask context processors used to
  inject.
* `static/` is organised by kind (`js/core|modules|pages|components`,
  `css/core|pages|print`, `fonts`, `images`, `samples`, `vendor`). Because
  waitress/gunicorn do not serve static files, `apps/core/views.static_file`
  serves `/static/…` through the staticfiles finders in every environment.

## Data access

Two layers share one SQLite file:

* **Django ORM** — sessions, admin, `accounts.User` (unmanaged, mapped to the
  legacy `users` table), sync devices/records/conflicts, audit fields.
* **Hand-written SQL** — `apps/core/db.py` and the services. A thread-local
  connection (`get_db()`) is closed at the end of each request by the
  compatibility middleware.

`CoreConfig.ready()` calls `ensure_database()` so a fresh checkout (or a
frozen desktop build with no administrator) starts with tables and seeds.
Migration `apps/core/migrations/0001_legacy_schema.py` performs the same
idempotent step for deployments that run `migrate` without starting the app.

## Modules

`apps/modules/services/` contains the ported business logic:

| Service | Responsibility |
| --- | --- |
| `attendance_service` | periods, scans, anti-passback, logs, closures |
| `entry_slip_service` / `exit_slip_service` | slip lifecycle, signatures, QR |
| `importer` | XLS/XLSX/HTML parsing, mapping, preview, commit |
| `report_service` | daily/monthly reports and XLSX workbooks |
| `sms_service` / `messaging_service` / `whatsapp_service` | gateways, jobs, campaigns |
| `scanner_bridge_service` | paired-phone scan polling |
| `update_service` | signed manifest verification and staged updates |
| `scheduler` | periodic jobs (closures, retries, update checks) |

The scheduler is started from `CoreConfig.ready()` only when
`START_BACKGROUND_JOBS` is true, the process is not a management command, and
(for `runserver`) the autoreloader child is the one running. Because `ready()`
runs once per WSGI worker, every process races for a non-blocking OS file lock
on `<DATA_DIR>/scheduler.lock` (`apps/core/runtime_lock.py`); only the winner
starts the threads. The OS releases the lock when the process exits, so a
restarted worker takes over automatically.

To keep the web workers idle, set `ATTENDANCE_BACKGROUND_JOBS=0` and run the
dedicated command instead:

```bash
python manage.py run_scheduler --interval 30
```

It takes the same lock, so a second copy exits instead of duplicating work.

## Synchronisation

`apps/synchronization` is native Django. Each change is stored as a
`SyncRecord` keyed by the client-generated UUID (idempotency) and a monotonic
`server_revision` per `(entity, entity_key)` (optimistic locking). Stale
`base_revision` values create a `SyncConflict` for administrator review
(`local`, `server` or `merged`). See `docs/api/README.md` for the protocol.

## Desktop

`desktop/launcher.py` is the entry point of the packaged build: it applies
`config.settings.desktop`, runs `migrate`, starts waitress, opens the browser
and shows a native dialog on startup failure. `TimeTrackEnterprise.spec` bundles the
templates, static files and locales. `config/desktop_security.py` restricts
hosts, cookies and `/admin/` (loopback only).
