# Testing

The project uses **pytest** + **pytest-django**. The configuration lives in
`pytest.ini`; the settings module is `config.settings.test`, which points
Django and the migrated functional layer at the **same temporary SQLite
file** (a real file, not `:memory:`, because `apps/core/db.py` keeps its own
connection).

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest                     # unit + integration
python -m pytest tests/unit          # services only
python -m pytest tests/integration   # HTTP stack + database
python -m pytest -k sync             # one feature
python -m pytest --cov=apps --cov=config --cov-report=term-missing
```

Django's own runner works too, but it cannot run the Flask-style tests:

```powershell
python manage.py test
```

## Layout

```
tests/
├── conftest.py          fixtures: app, client, anon, csrf, db, make_student, period
├── support.py           Flask-style CompatClient/CompatResponse on django.test.Client
├── unit/                services, i18n, importers, update signing, sync services
├── integration/         pages, auth, attendance, slips, reports, sync API
└── e2e/                 Node camera-scan test + manual desktop checklist
```

## Test database

`config/settings/test.py` pins `DATABASES["default"]["TEST"]["NAME"]` to the
same file as `DB_PATH`. Django creates that file once per session (migrations
included), then the autouse `legacy_schema` fixture in `tests/conftest.py`:

1. drops the hand-written tables (`users`, `students`, `periods`, ...);
2. calls `ensure_database()`, which recreates and reseeds them (administrator,
   settings, default period);
3. installs fresh `sms_jobs` / `message_jobs` managers on the test app.

Tests therefore start from a known state even though the legacy layer writes
outside Django's transaction. `transactional_db` is used (instead of `db`) so
those writes commit and both connections see them.

The `db` fixture is **not** pytest-django's fixture: it returns a dedicated
`sqlite3` connection for raw-SQL assertions, because request handlers close
the compatibility connection at the end of every response.

## Writing a test

Use the `client` fixture (authenticated administrator) for pages and the
migrated API; use `anon` for anonymous flows:

```python
def test_student_lifecycle(client, csrf, make_student):
    student = make_student(class_group="2AS1")
    assert client.get(f"/api/students/{student['student_nin']}").status_code == 200

def test_anonymous_is_guarded(anon):
    assert anon.get("/").status_code == 302
```

The compatibility client understands the Flask idioms still used by the
migrated tests: `json=`, `query_string=`, `headers=`, `follow_redirects=`,
`set_cookie()`, `session_transaction()`, `get_json()`, `get_data(as_text=True)`,
`.data`, `.mimetype` and `.content_type`.

Mutating `/api/` calls must send `X-Requested-With: StudentAttendance`
(the `csrf` fixture); device clients use `X-Device-Token` instead.

## Markers

Tests are tagged `unit`, `integration` (used by the sync suites). Run them
with `-m unit` / `-m integration`. `--strict-markers` is enabled, so declare
new markers in `pytest.ini`.

## Static analysis

```powershell
python -m ruff check apps config tests desktop manage.py
python -m compileall -q apps config desktop manage.py
python manage.py check --deploy --settings=config.settings.production
```

## Front-end test

```powershell
node --test tests/e2e/test_camera_scan.cjs
```

## Continuous integration

A minimal pipeline is:

1. `pip install -r requirements-dev.txt`
2. `python manage.py check`
3. `python -m pytest`
4. `node --test tests/e2e/test_camera_scan.cjs`
5. `python -m ruff check .`

Never run the production settings against the real `data/TimeTrackEnterprise.db` in a
test: always use `config.settings.test` (or a copy of the database).
