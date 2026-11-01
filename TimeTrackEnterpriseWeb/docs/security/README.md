# Security

The application runs inside a school, usually on a teacher's workstation or on
a small server. It holds student records, photos and parent phone numbers, so
the threat model is closer to a records system than to a public website:

| Asset | Where it lives |
| --- | --- |
| Student records, attendance, phone numbers | `data/TimeTrackEnterprise.db` |
| Student photos, school logo, stamp | `data/photos`, `data/uploads` |
| Session keys, update signing key | `data/.secret_key`, `secrets/` (never deployed) |
| Paired Android devices | `sync_devices` table + tokens |

Trust boundaries:

1. **The browser/desktop session** — a member of staff using the machine.
2. **The school LAN** — phones used as scanners and, optionally, other
   workstations. Not trusted by default.
3. **The internet** — only the reverse proxy. The WSGI server is never
   published directly.
4. **Third parties** — the SMS gateway, WhatsApp Cloud API and the update
   feed. They only receive data when an administrator triggers an action.

## Authentication

* Accounts live in the legacy `users` table; passwords are **Werkzeug PBKDF2**
  hashes. `apps/accounts/backends.py::LegacyBackend` verifies them and bridges
  the record to Django's authentication API.
* The first administrator (`admin`) is seeded **without a password** so the
  school can log in on a fresh install. This is safe only until the first
  login: set a password from **الإعدادات → المستخدمون** immediately. On a
  networked deployment, do it before opening the port.
* A password is optional for subsequent accounts; an account without one logs
  in with its username only. Use passwords for every account on a shared
  server.
* Login failures are throttled twice: per `username|remote address` (5
  failures / 5 minutes in `apps/accounts/views.py`) and per client IP
  (20 `POST /login` / 5 minutes in
  `apps/core/middleware/rate_limit.py`). Counters are in memory: behind
  several gunicorn workers the effective limit is per worker, so keep the
  proxy-level limit or a single worker for exposed deployments.
* A successful login calls `session.clear()` (Django `flush()`), which
  discards the old session and issues a new key, then rotates the CSRF token.
* Sessions last 12 hours (`SESSION_COOKIE_AGE`), are `HttpOnly`,
  `SameSite=Lax`, and `Secure` under `config.settings.production`.
* Logout is a `POST` protected by the CSRF token.

## Authorization

`apps/accounts/middleware.py::AccountGateMiddleware` is the single gate:

* unauthenticated page requests redirect to `/login?next=…` (the `next`
  target is validated to a local path);
* unauthenticated `/api/` requests receive `401` with
  `{"ok": false, "error": {"code": "auth_required"}}`;
* administrator-only API prefixes: `/api/settings`, `/api/uploads`,
  `/api/users`, `/api/system/*`, `/api/update/*`,
  `/api/messages/gateway/pair`, and period mutations;
* every mutating `/api/` request must send
  `X-Requested-With: StudentAttendance` (except sync calls authenticated by a
  device token).

The account service refuses to delete or demote the last active administrator
and refuses self-deletion/self-deactivation.

`/admin/` is Django's own interface. It uses the same users, but:

* it is not linked from the application UI;
* on the desktop build `config/desktop_security.py` rejects `/admin/` from
  anything but loopback;
* put it behind the proxy's authentication or block it entirely on a public
  server (`location /admin/ { return 404; }`).

## CSRF

There are two mechanisms, matching the two generations of the codebase:

| Requests | Protection |
| --- | --- |
| Migrated Flask views (`/login`, `/logout`, legacy `/api/…`) | session `csrf_token` + `X-Requested-With: StudentAttendance` |
| Native Django views (`/admin/`, sync session endpoints) | Django `CsrfViewMiddleware` |

The migrated views are deliberately `csrf_exempt`: the legacy jQuery client
does not read the `csrftoken` cookie, and browser clients cannot add a custom
header to a cross-site form submission without a CORS preflight. Combined with
`SameSite=Lax` cookies this blocks classic cross-site POSTs. It is **not** a
substitute for a real CSRF token inside the same origin — an XSS bug bypasses
it, which is why the CSP forbids inline scripts.

Device clients send `X-Device-Token`; the sync views validate the token and
ignore the session. A token is scoped to `/api/sync/` and cannot be used to
open pages.

## Transport and headers

Set by `apps/core/middleware/compat.py` and Django:

| Header | Value |
| --- | --- |
| `Content-Security-Policy` | `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'; font-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'` |
| `X-Frame-Options` | `DENY` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `same-origin` |
| `Strict-Transport-Security` | production only, 1 year, subdomains, preload |
| `Cache-Control` | `no-store` on `/api/` |

CSP is also set in `config/settings/production.py`, so a misconfigured proxy
cannot silently drop it. `style-src` allows inline styles because templates
use small `style=""` attributes for print layout; no third-party script,
font or image is loaded.

TLS is mandatory for `config.settings.production`: secure cookies, HSTS and
`SECURE_SSL_REDIRECT`. When Nginx terminates TLS, set
`ATTENDANCE_SSL_REDIRECT=0` and make sure Nginx sends
`X-Forwarded-Proto: https` (the provided configuration does).

## Input validation and data access

* JSON bodies are parsed defensively; invalid payloads return `400` and never
  reach a query.
* Student NINs, roles, phones, period times, slip reasons, statuses and
  settings keys are validated in the service layer before use.
* All SQL uses `?` placeholders; dynamic fragments (sort columns, status
  lists) are chosen from fixed allowlists. The hand-written layer
  (`apps/core/db.py`, `apps/modules/services/`) is audited for string
  interpolation.
* Request size is capped at **30 MiB** (`DATA_UPLOAD_MAX_MEMORY_SIZE`,
  `FILE_UPLOAD_MAX_MEMORY_SIZE`, `MAX_CONTENT_LENGTH`), with 5 000 form
  fields.
* Imports accept XLS/XLSX/HTML only, are sniffed by content and limited in
  row count.

### Uploads

`apps/core/media.py::save_image`:

* reads at most 5 MiB and rejects empty files;
* checks the **magic bytes** (JPEG, PNG, WEBP), not the extension;
* names the file from the SHA-256 digest (`logo_<digest>.png`), so a crafted
  name cannot escape the folder or overwrite another upload;
* writes only inside `PHOTOS_DIR` / `UPLOADS_DIR`.

`send_from_directory`-style responses resolve the requested path and reject
anything outside the media folder (path traversal). Brand images under
`/media/uploads/` are public (the login page shows the school logo); student
photos under `/media/photos/` require an authenticated session, even though
their digest-based names make them hard to guess.

## Secrets

| Secret | Storage |
| --- | --- |
| Django `SECRET_KEY` | `ATTENDANCE_SECRET_KEY`, or generated into `DATA_DIR/.secret_key` |
| Update signing key (Ed25519 private) | `secrets/update_signing_key.pem`, outside the repository |
| SMS gateway API key | application settings (database) |
| WhatsApp access token | application settings (database) |

Rules:

* `.gitignore` excludes `secrets/`, `.env*`, `*.pem` and `*.key`.
* Losing the update signing key means shipping a new public key in a new
  release; back it up offline.
* The SQLite file and `data/` must not be readable by other OS users. On
  Linux: `chown -R timetrack:timetrack /var/lib/timetrack && chmod 700`.
* Device tokens are stored in plain text so the server can authenticate the
  request; treat a database backup as a set of credentials and revoke devices
  after restoring one.

## Updates

`apps/modules/services/update_service.py` verifies the **Ed25519** signature
of `latest.json` with the public key embedded in the build before parsing the
asset list, then checks **SHA-256** and the size of each downloaded file.
Unsigned or modified manifests are rejected. HTTPS is required for the feed.
The installer is only executed after that check, and the private key never
ships with the application.

## Desktop hardening

* `config/settings/desktop.py` accepts only loopback, the machine name and
  the machine's private addresses (`config/desktop_security.py`).
* `/admin/` is loopback-only; the scanner/sync API remains reachable from the
  school LAN.
* Cookies are not `Secure` because the desktop serves HTTP on loopback; never
  set `--host 0.0.0.0` outside a trusted network.
* The desktop build shows student data on the workstation; use an OS account
  with a screen lock and keep `data/` on an encrypted disk when possible.

## Logging and privacy

* `data/logs/app.log` rotates at 2 MiB with 3 backups.
* Passwords, tokens and full request bodies are never logged. Error handlers
  log the exception, not the payload.
* SMS content and recipient numbers exist in `sms_logs` / `message_outbox`.
  Backups therefore contain personal data; encrypt them at rest and delete
  old copies (`scripts/backup.py --keep 14` prunes automatically).
* Third-party calls only happen on explicit administrator actions (test SMS,
  campaign send, update check). The default `sms_test_mode=1` simulates
  delivery without network access.

## Known limitations

* CSRF for migrated endpoints relies on a custom header plus `SameSite=Lax`,
  not a per-request token. XSS would defeat it; CSP and server-side escaping
  are the defence. Do not add `'unsafe-inline'` to `script-src`.
* Rate limiting is per process and in memory. For an internet-facing
  deployment add `limit_req` in Nginx.
* SQLite has no per-row access control. Anyone with the file has every
  student record; this is an on-premise design.
* The seeded passwordless `admin` is a deliberate usability trade-off for a
  classroom install, not something to expose before setting a password.

## Review checklist

- [ ] `python manage.py check --deploy --settings=config.settings.production`
      is clean.
- [ ] `DEBUG` is false and `SECRET_KEY` comes from the environment.
- [ ] The seeded administrator has a strong password.
- [ ] TLS is active and `ALLOWED_HOSTS` / `CSRF_TRUSTED_ORIGINS` match the
      public name.
- [ ] `/admin/` is blocked or protected on internet-facing deployments.
- [ ] `data/`, backups and `secrets/` are not world-readable and are excluded
      from git and Docker contexts.
- [ ] Every paired device in **الإعدادات → المزامنة** is expected; revoke the
      rest.
- [ ] Templates avoid `|safe` on user input; review before adding it.
- [ ] New SQL uses placeholders and allowlisted sort columns.
- [ ] New uploads go through `apps/core/media.save_image`.
