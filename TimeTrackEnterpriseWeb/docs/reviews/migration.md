# Migration review: legacy application → Django

**Reference:** the former Flask source tree (verified route-by-route, then
removed from this machine; it is no longer part of the project).
**Target tree:** `4444.txt`.
**Result:** the legacy entry point and package were removed; every route,
service and template now lives in the Django project, which is the only
runtime.

## Approach

The functional code (SQL, validation, reporting, messaging, slips, imports)
was migrated with minimal changes. Framework behaviour was replaced by a
compatibility layer instead of rewriting business logic, so each route could
be compared with the original:

| Flask | Replacement | File |
| --- | --- | --- |
| `Flask`, `Blueprint`, route decorators | Django `path()` + `csrf_exempt` wrappers | `apps/core/compat.py` |
| `request`, `g`, `session`, `current_app` | request-scoped ContextVar proxies | `apps/core/compat.py` |
| `jsonify`, `Response`, `send_file`, `abort` | Django responses / `FileResponse` | `apps/core/compat.py` |
| `render_template` | Jinja2 backend + `LayoutLoader` | `config/jinja2.py`, `apps/core/templating.py` |
| `url_for` | `django.urls.reverse` with Flask converters | `apps/core/compat.py` |
| `before_request` auth/CSRF/admin guards | `AccountGateMiddleware` | `apps/accounts/middleware.py` |
| `after_request` headers/i18n/digits | `CompatRequestMiddleware` | `apps/core/middleware/compat.py` |
| SQLite helpers | thread-local `sqlite3` connection | `apps/core/db.py` |

The compatibility views never call `django.shortcuts.render`; they render the
already-configured Jinja template directly, so the Flask-style context (and
the Arabic translator) behaves exactly as before.

## What moved where

| Legacy module | Django location |
| --- | --- |
| `app.py` | `desktop/launcher.py`, `manage.py`, `config/wsgi.py`, `config/asgi.py` |
| `attendance_app/db.py` | `apps/core/db.py` |
| `attendance_app/config.py` | `apps/core/config.py` (re-exported in `config.settings.base`) |
| `attendance_app/compat.py` | `apps/core/compat.py` |
| `attendance_app/i18n.py` | `apps/core/i18n.py` + `apps/core/locales/` |
| `attendance_app/views.py` | `apps/modules/views.py` |
| `attendance_app/api.py` | `apps/modules/api.py` |
| `attendance_app/services/*` | `apps/modules/services/*` |
| `attendance_app/templates/*` | `templates/{base,pages,partials,components,print}/` |
| `attendance_app/static/*` | `static/{js,css,fonts,images,samples,vendor}/` |
| `attendance_app/locales/*` | `apps/core/locales/*` |
| (session auth helpers) | `apps/accounts/*` |
| (new) | `apps/synchronization/*` — native Django sync protocol |

## Route and behaviour parity

Checked against the former implementation (before it was removed):

* **Pages:** `/`, `/gate`, `/students`, `/import`, `/attendance`, `/messages`,
  `/reports`, `/print/sheet`, `/reports/print`, `/entry-slip`,
  `/entry-slip/verify`, `/exit-slip`, `/settings`, `/users`, `/help`,
  `/about`, `/login`.
* **JSON API:** ~75 endpoints under `/api/` (students, periods, imports,
  attendance, gate, slips, SMS/messaging, reports, printing, users, settings,
  updates, backup, uploads, scanner bridge). The legacy no-trailing-slash form
  is preserved.
* **Response shape:** `{"ok": true, …}` / `{"ok": false, "error": {"code",
  "message"}}`, UTF-8 Arabic, Arabic-Indic digits normalised.
* **Guard:** `X-Requested-With: StudentAttendance` on every mutating session
  call, admin prefixes, login redirect with validated `next`.
* **Sessions:** `user_id` in the Django session, 12-hour lifetime, Werkzeug
  PBKDF2 passwords, last-admin protection.
* **Background jobs:** scheduler started from `CoreConfig.ready()` only for
  the serving process (management commands and the `runserver` parent are
  skipped). A cross-process file lock (`DATA_DIR/scheduler.lock`) guarantees a
  single scheduler even with several WSGI workers; `manage.py run_scheduler`
  runs it in the foreground when the web workers must stay idle.
* **Static files:** `/static/` served through staticfiles finders, because
  waitress and gunicorn do not serve them.
* **Templates:** flat legacy names (`dashboard.html`) resolved by
  `LayoutLoader` to the new folders; every reference was rewritten to the new
  static paths.

## Database

One SQLite file is shared by both layers:

* hand-written legacy tables (`users`, `students`, `periods`,
  `attendance_logs`, `sms_logs`, `period_closures`, `entry_slips`,
  `exit_slips`, `message_campaigns`, `message_outbox`, `settings`,
  `app_meta`), created by `apps/core/db.py::SCHEMA` (`user_version = 5`);
* Django tables (sessions, admin, sync).

`ensure_database()` runs from `CoreConfig.ready()` and from the idempotent
migration `apps/core/migrations/0001_legacy_schema.py`, so both a fresh
checkout and a deployed `migrate` produce the same schema. `accounts.User` is
`managed = False` and maps the existing `users` table; no migration ever
alters it.

## Tests

Legacy tests were rewritten in place:

| Legacy area | New file |
| --- | --- |
| attendance, i18n, importer, messaging, scanner bridge, updates, WhatsApp | `tests/unit/test_*.py` |
| app core, auth, entry/exit slips, reports/printing | `tests/integration/test_*.py` |
| browser camera scan (Node) | `tests/e2e/test_camera_scan.cjs` |
| (new) sync services and API | `tests/unit/test_sync_services.py`, `tests/integration/test_sync_api.py` |

`tests/support.py` provides a Flask-style `CompatClient` over
`django.test.Client` (`json=`, `query_string=`, `follow_redirects=`,
`session_transaction()`, `get_json()`, `.mimetype`, …), so the original
assertions survived the migration.

The test database is a **file**, not `:memory:`, because the legacy layer
opens its own `sqlite3` connection. `tests/conftest.py` drops and reseeds the
legacy tables around every test (`transactional_db`), since Django's `flush`
does not know about them.

## Verification status

| Check | Status |
| --- | --- |
| Module-by-module read-through against the former implementation | done (static) |
| Imports, URL names, template names cross-checked with search | done (static) |
| `python manage.py check` | **not run** — no Python/Django in the review environment |
| `python manage.py migrate` | **not run** |
| `python -m pytest` | **not run** — tests authored and reviewed only |
| `node --test tests/e2e/test_camera_scan.cjs` | **not run** |
| Desktop build (`build.bat`) and manual checklist | **not run** |
| Flutter client (`flutter analyze` / `flutter test`) | **not run** |

## Open items

1. Run the commands above on a machine with Python 3.11+ and report failures;
   expect small fixes in `tests/conftest.py` ordering and any missed template
   reference.
2. Confirm the seeded administrator can log in with an empty password on a
   fresh `data/` folder, then change it.
3. Exercise the desktop launcher once (port fallback, browser opening, native
   error dialog) and the PyInstaller bundle (`build.bat`).
4. Verify the scanner bridge long-poll through Nginx (timeouts, proxy
   buffering).
5. Run one real SMS/WhatsApp test in test mode and one against a real gateway
   before production use.
6. ~~Review `templates/partials/print_card.html` and
   `templates/components/print_card.html` for duplication; keep one if the
   later cleanup confirms both are unused/used.~~ **Done** — see item 8.
7. ~~Remove the temporary `scripts/_i18n_*.txt` extraction files if the locale
   build no longer needs them.~~ **Done** — they were build artefacts; the
   checked-in catalogs live in `apps/core/locales/`.
8. ~~Deduplicate `print_card`/`print_sticker`.~~ **Done** — the canonical
   copies live in `templates/components/` (as required by `4444.txt`); the
   unused `templates/partials/` duplicates were removed and
   `templates/print/print_sheet.html` now includes the component paths.
