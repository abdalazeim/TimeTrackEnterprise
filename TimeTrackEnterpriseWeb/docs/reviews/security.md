# Security review

Scope: the migrated Django application, its settings, the authentication gate,
the sync API and the deployment templates added in this change.

Method: manual review of every security-relevant module plus a search for
common anti-patterns (string-formatted SQL, `|safe`, `DEBUG`, wildcard hosts,
hard-coded secrets, `csrf_exempt`, path joins, upload validation). The
environment had no Python interpreter, so **no dynamic test was executed**
(`manage.py check --deploy`, `pytest`, a browser session) — see
[`README.md`](README.md).

## Findings

| # | Severity | Finding | Status |
| --- | --- | --- | --- |
| 1 | Medium | Student photos under `/media/photos/` were reachable without a session, because the account gate skipped all of `/media/`. | **Fixed** — only `/media/uploads/` (logo/stamp) is public now; photos require login. Re-test after deployment. |
| 2 | Medium | Login rate limits are held in process memory. With `GUNICORN_WORKERS=3` the effective limit triples, and a restart clears it. | Accepted; documented in `docs/security/README.md`. Add `limit_req` in Nginx for internet-facing installs. |
| 3 | Medium | The first administrator is seeded **without a password**, so a fresh network-exposed instance can be entered by typing `admin`. | Accepted for a classroom install; the installation checklist requires setting a password before exposing the port. |
| 4 | Low | Migrated `/api/` mutations use `X-Requested-With: StudentAttendance` instead of a per-request CSRF token. | Accepted. The header cannot be sent by a cross-site HTML form without a CORS preflight, cookies are `SameSite=Lax`, and CSP blocks inline script (the usual way to forge the request). Native views keep Django CSRF. |
| 5 | Low | `style-src 'unsafe-inline'` in the CSP. | Accepted: templates use inline `style=""` for print geometry. `script-src` remains `'self'`; do not relax it. |
| 6 | Low | Login throttling does not apply to `/admin/`; Django's admin has no lockout. | Accepted on the desktop (loopback-only admin); block `/admin/` at the proxy on public servers. |
| 7 | Low | Student photos and brand images are named from a SHA-256 digest, which is not a secret. | Acceptable once the session gate applies; keep uploads out of public search engines (`robots.txt`/proxy) if the instance is internet-facing. |
| 8 | Low | Device sync tokens are stored in plain text and are included in database backups. | By design (the server must validate the token). Revoke devices after restoring a backup; protect backups as credentials. |
| 9 | Low | Default password policy is a 6-character minimum, enforced by the account service; Django's richer validators only apply to admin forms. | Accepted for a local school tool; raise `PASSWORD_MIN` in `apps/accounts/services.py` for shared servers. |
| 10 | Info | Automatic updates download and execute binaries. | Mitigated by Ed25519 manifest verification + SHA-256/size checks; the private key must stay offline. Compromise of that key is equivalent to remote code execution on every install. |
| 11 | Info | Cookies are not `Secure` in the desktop build. | Intentional: the desktop serves HTTP on loopback. `config.settings.production` enables `Secure`, HSTS and TLS redirect. |
| 12 | Info | SQLite has no per-row authorization; anyone with the file has all records. | Inherent to the on-premise design. Protect the `data/` folder and backups at OS level. |

## Verified controls

* **Settings split:** `production.py` sets `DEBUG=False`, environment-driven
  `ALLOWED_HOSTS`/`CSRF_TRUSTED_ORIGINS`, secure cookies, HSTS, TLS redirect
  and the proxy header. `desktop.py` narrows hosts to loopback/private
  addresses.
* **Gate coverage:** `AccountGateMiddleware` runs after
  `SessionMiddleware` + `CompatRequestMiddleware` in `base.py` and
  `desktop.py`, so `g.user` is always populated before the decision. Public
  routes are an explicit allowlist (login, health, i18n catalog, favicon,
  media uploads). API denials return JSON, pages redirect with a validated
  `next`.
* **Admin prefixes:** settings, users, uploads, backup, shutdown, update
  check/install, gateway pairing and period mutations are admin-only.
* **Device path:** `/api/sync/` bypasses the session gate **only** when
  `X-Device-Token` is present, and every sync view validates the token against
  `Device.is_active`.
* **Session handling:** `flush()` on login and logout (new session key), CSRF
  token rotated after login, 12-hour lifetime, `HttpOnly`, `SameSite=Lax`.
* **Password storage:** Werkzeug PBKDF2 (unchanged from the legacy system);
  no password is ever returned by the API (`has_password` boolean only).
* **Login enumeration:** a wrong username and a wrong password produce the
  same message; account creation is admin-only.
* **Uploads:** magic-byte validation, 5 MiB cap, digest filenames, containment
  check in `save_image`/`safe_delete_media`; 30 MiB request cap.
* **Static files:** resolved through `django.contrib.staticfiles.finders`, never
  by joining `request.path` to a directory.
* **No CORS middleware:** the API is same-origin by construction, which closes
  the cross-origin variant of the custom-header CSRF guard.
* **Errors:** handlers log the exception server-side and return a localised
  message without stack traces; `DEBUG` is off in production.
* **Secrets:** `.gitignore`/`.dockerignore` exclude `secrets/`, `.env*`, `*.pem`,
  `*.key`, databases and runtime data. Docker requires a secret key to be
  supplied explicitly.
* **Dependency pinning:** `requirements.txt` pins every runtime package.

## Deployment recommendations

1. Terminate TLS at Nginx/IIS and never publish gunicorn/waitress directly.
2. Set `ATTENDANCE_SECRET_KEY` from a secret store; rotate it only together
   with a session flush (all users are logged out).
3. Restrict `/admin/` (`allow 10.0.0.0/8; deny all;` or a proxy auth layer).
4. Add `limit_req_zone` for `/login` and `/api/`.
5. Run the service as a dedicated user; `chmod 700` on the data folder.
6. Keep `ATTENDANCE_BACKGROUND_JOBS=1` on exactly one process, or set it to `0`
   and run `python manage.py run_scheduler` as a separate service. The
   `DATA_DIR/scheduler.lock` file lock prevents duplicate schedulers anyway.
7. Encrypt off-site backups and test a restore at least once.
8. Subscribe to Django security releases; upgrade within the supported window
   (the project pins Django 5.2 LTS).

## Re-test checklist

After installing the environment:

```bash
python manage.py check --deploy --settings=config.settings.production
python -m pytest tests/integration/test_auth.py tests/integration/test_sync_api.py
```

Then, in a browser:

* request `/media/photos/<existing-photo>` while logged out → redirect/401;
* request `/media/uploads/<logo>` while logged out → 200;
* POST `/api/students` without `X-Requested-With` → `403 csrf`;
* call `/api/sync/push/` without a token → `401`;
* log in with a wrong password five times → `429`.
