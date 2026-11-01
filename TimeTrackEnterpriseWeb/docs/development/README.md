# Development

## Requirements

* Python 3.11+ (3.13 recommended)
* Node 20+ (only for the camera-scan test)
* Flutter 3.24+ (optional, `GDS-Android-Template`)

## Setup

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
python manage.py migrate
python manage.py runserver
```

Open <http://127.0.0.1:8000/>. The first administrator is `admin` with **no
password**; set one from **الإعدادات → المستخدمون** immediately.

`run.bat` does the same and starts the desktop launcher on
<http://127.0.0.1:8765/>.

## Settings modules

| Module | Use |
| --- | --- |
| `config.settings.base` | shared defaults |
| `config.settings.development` | `DEBUG=True`, hosts `*`, auto-reload |
| `config.settings.local` | developer machine overrides (`local.py` is git-ignored) |
| `config.settings.desktop` | frozen launcher: portable `data/`, waitress, loopback admin |
| `config.settings.production` | HTTPS, HSTS, secure cookies, env-driven hosts |
| `config.settings.test` | pytest: temporary file DB, no workers |
| `config.settings.test_postgres` | optional Postgres run of the Django tests |

Select one with `DJANGO_SETTINGS_MODULE` or
`python manage.py <cmd> --settings=config.settings.production`.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `DJANGO_SETTINGS_MODULE` | `config.settings.development` | settings module |
| `ATTENDANCE_DATA_DIR` | `<project>/data` | database, photos, uploads, logs, updates |
| `ATTENDANCE_DB_PATH` | `DATA_DIR/attendance.db` | explicit database file |
| `ATTENDANCE_SECRET_KEY` | generated into `DATA_DIR/.secret_key` | signing/session key |
| `ATTENDANCE_ALLOWED_HOSTS` | `localhost,127.0.0.1` | production hosts |
| `ATTENDANCE_CSRF_TRUSTED_ORIGINS` | empty | comma-separated origins |
| `ATTENDANCE_SSL_REDIRECT`, `ATTENDANCE_HSTS_SECONDS` | `1`, `31536000` | HTTPS policy |
| `ATTENDANCE_BACKGROUND_JOBS` | `1` | desktop scheduler on/off |
| `ATTENDANCE_DISABLE_SCHEDULER` | `0` | disable workers |
| `ATTENDANCE_THREADS` | `8` | waitress threads |

## Layout

```
config/        settings, URLs, WSGI/ASGI, Jinja environment, desktop hardening
apps/core/     compat bridge, DB, i18n, templating, middleware, errors, backup
apps/accounts/ sessions, roles, AccountGateMiddleware, LegacyBackend
apps/modules/  pages (views.py), legacy JSON API (api.py), services/
apps/synchronization/  devices, push/pull, conflicts
templates/     base/, pages/, partials/, components/, print/
static/        js/{core,modules,pages,components}, css/{core,pages,print}, ...
tests/         unit/, integration/, e2e/
scripts/       build, icons, locales, demo data, update signing, backup/restore
deployment/    docker/, gunicorn/, nginx/
desktop/       launcher.py (packaged entry point)
```

## Adding a page or API route

Migrated routes use the compatibility blueprint:

```python
# apps/modules/views.py
@views_bp.get("/my-page")
def my_page():
    return render_template("my_page.html", **_page_context("my_page", "العنوان"))

# apps/modules/api.py — no trailing slash, like Flask
@api_bp.get("/my-endpoint")
def my_endpoint():
    return jsonify(ok=True, items=[...])
```

Add the template under `templates/pages/` (the `LayoutLoader` resolves the flat
name). Native Django views live in `apps/core`, `apps/accounts` or
`apps/synchronization` and are registered in the matching `urls.py` /
`api_urls.py`. Mount order in `config/api_urls.py` matters: specific prefixes
(`sync/`, `accounts/`, `core/`) come before the legacy catch-all.

Mutating session API calls need the `X-Requested-With: StudentAttendance`
header; `csrf_exempt` is intentional (the guard is in `AccountGateMiddleware`)
because the legacy jQuery client sends that header instead of a CSRF token.

## Internationalisation

`apps/core/i18n.py` holds the runtime translator. Catalogs are
`apps/core/locales/en.json` and `fr.json` (Arabic is the source language).
Edit them and run:

```powershell
python scripts/build_locales.py
```

Templates use `{{ "text"|t }}`; Python code uses `i18n.translate("text")`.
Arabic-Indic digits are normalised to Western digits in every response.

## Common commands

```powershell
python manage.py check
python manage.py makemigrations && python manage.py migrate
python manage.py collectstatic --noinput
python manage.py shell
python manage.py run_scheduler         # foreground workers (lock-protected)
python scripts/seed_demo.py            # demo students (development only)
python scripts/backup.py
python -m pytest
```

## Static assets

The project ships plain ES modules; there is no bundler step. Keep page
scripts in `static/js/pages/`, shared helpers in `static/js/core/`, module
behaviour in `static/js/modules/` and print widgets in
`static/js/components/`. Templates reference `url_for('static', filename=...)`,
which resolves to `/static/<path>`.

## Adding a new module

Create the package under `apps/modules/services/`, keep the business logic free
of framework imports where possible, and reuse the shared bridges:

1. Put pure logic in `apps/modules/services/<name>.py`.
2. Import the compatibility helpers from `apps.core.compat` (`request`, `g`,
   `session`, `current_app`, `url_for`) and the database helpers from
   `apps.core.db` (`get_db`, `get_settings`, `save_settings`).
3. Register routes on a `Blueprint` and include its patterns in `apps/<app>/urls.py`
   or `apps/<app>/api_urls.py`.
4. Add a test under `tests/integration/` using the `client`/`csrf` fixtures.
