# Deployment

Three deployment shapes are supported. They all run the **same** Django
project and the same SQLite schema; only the process manager and the data
folder differ.

| Shape | Best for | Server | Settings |
| --- | --- | --- | --- |
| Desktop EXE | A single school workstation | waitress, loopback | `config.settings.desktop` |
| Linux/Docker | A school server or VPS | gunicorn + Nginx | `config.settings.production` |
| Windows service | An existing Windows server | waitress (NSSM/Task Scheduler) | `config.settings.production` |

> The application stores everything in one SQLite file. Never point two
> containers or two machines at the same database file over a network share.
> Scale by giving each school its own instance, not by sharing one database.
> Attendance uses the school timezone (`Africa/Algiers`). Set the host OS
> timezone accordingly for non-Docker production deployments; the Docker image
> sets `TZ=Africa/Algiers`.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `DJANGO_SETTINGS_MODULE` | `config.settings.development` | settings module |
| `ATTENDANCE_DATA_DIR` | `data/` next to the project | database, photos, uploads, logs, updates |
| `ATTENDANCE_DB_PATH` | `DATA_DIR/TimeTrackEnterprise.db` | explicit database file |
| `ATTENDANCE_SECRET_KEY` | generated in `DATA_DIR/.secret_key` | sessions and signing (required in Docker) |
| `ATTENDANCE_ALLOWED_HOSTS` | `localhost,127.0.0.1` | comma-separated host names |
| `ATTENDANCE_CSRF_TRUSTED_ORIGINS` | empty | comma-separated `https://…` origins |
| `ATTENDANCE_TRUST_X_REAL_IP` | `0` | trust `X-Real-IP` only behind a proxy that overwrites it |
| `ATTENDANCE_SSL_REDIRECT` | `1` (production) | set to `0` when Nginx terminates TLS |
| `ATTENDANCE_HSTS_SECONDS` | `31536000` | HSTS lifetime |
| `ATTENDANCE_BACKGROUND_JOBS` | `1` | period closures, SMS retries, update checks |
| `ATTENDANCE_DISABLE_SCHEDULER` | `0` | disable the scheduler |
| `ATTENDANCE_THREADS` | `8` | waitress threads (desktop) |
| `GUNICORN_WORKERS` / `GUNICORN_THREADS` | `3` / `4` | gthread workers (Docker) |

Generate a secret with:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

## Docker + Nginx + gunicorn

Files:

```
deployment/
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── .env.example
├── gunicorn/gunicorn.conf.py
└── nginx/
    ├── timetrack.conf
    └── certs/            fullchain.pem + privkey.pem
```

### 1. Certificates

Put `fullchain.pem` and `privkey.pem` in `deployment/nginx/certs/` (see the
README in that folder for a self-signed test pair). Nginx serves HTTPS on
`443`, redirects `80` to it and proxies to the `web` container on the internal
network.

### 2. Configuration

```bash
cd deployment/docker
cp .env.example .env
# edit hosts, CSRF origin and ATTENDANCE_SECRET_KEY
```

### 3. Build and start

```bash
docker compose up -d --build
docker compose logs -f web
```

The container entrypoint runs, in order:

1. `python manage.py migrate --noinput` — Django tables **and** the legacy
   schema (`apps/core/migrations/0001_legacy_schema.py`);
2. `python manage.py collectstatic --noinput` — into the `static_files`
   volume mounted at `/srv/static` in Nginx;
3. `gunicorn config.wsgi:application --config deployment/gunicorn/gunicorn.conf.py`.

The first start seeds the `admin` account (no password) and the default
morning period. Log in immediately and set a password from **الإعدادات →
المستخدمون**.

### 4. Volumes

| Volume | Container path | Content |
| --- | --- | --- |
| `attendance_data` | `/app/data` | `TimeTrackEnterprise.db`, photos, uploads, logs, update staging |
| `static_files` | `/app/staticfiles` → `/srv/static` | collected static assets |

Back them up together: the database references photo filenames, and the
update staging folder must survive restarts.

```bash
docker compose exec web python scripts/backup.py --output /app/data/backups
docker compose cp web:/app/data/backups/. ./backups/
```

`scripts/backup.py` uses SQLite's online backup API, so it is safe while the
app is running.

### 5. Upgrade

```bash
docker compose build --pull
docker compose up -d
```

Migrations run automatically. Keep the previous image tag so you can roll
back; the previous `attendance.db` remains available while the new
`TimeTrackEnterprise.db` is used by the renamed application. Restore the database
together with the matching image if a schema
change ever needs to be undone.

## systemd (Linux without Docker)

```ini
# /etc/systemd/system/timetrack.service
[Unit]
Description=TimeTrack Enterprise
After=network.target

[Service]
User=timetrack
Group=timetrack
WorkingDirectory=/opt/timetrack
Environment=DJANGO_SETTINGS_MODULE=config.settings.production
Environment=ATTENDANCE_DATA_DIR=/var/lib/timetrack
Environment=ATTENDANCE_ALLOWED_HOSTS=attendance.example.org
EnvironmentFile=/etc/timetrack.env
ExecStartPre=/opt/timetrack/.venv/bin/python manage.py migrate --noinput
ExecStartPre=/opt/timetrack/.venv/bin/python manage.py collectstatic --noinput
ExecStart=/opt/timetrack/.venv/bin/gunicorn config.wsgi:application \
    --config /opt/timetrack/deployment/gunicorn/gunicorn.conf.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Then place `deployment/nginx/timetrack.conf` in
`/etc/nginx/conf.d/`, change the upstream from `web:8000` to
`127.0.0.1:8000`, and change the static alias to the real `staticfiles/`
path. `ATTENDANCE_SECRET_KEY`, mail/SMS credentials and other secrets belong
in `/etc/timetrack.env` (mode `600`), not in the unit file.

## Windows server

The desktop build is the simplest option. For a headless Windows server:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:DJANGO_SETTINGS_MODULE = "config.settings.production"
$env:ATTENDANCE_ALLOWED_HOSTS = "attendance.example.org"
$env:ATTENDANCE_SSL_REDIRECT = "0"
.\.venv\Scripts\python.exe manage.py migrate --noinput
.\.venv\Scripts\python.exe manage.py collectstatic --noinput
```

Run `waitress-serve --listen=127.0.0.1:8000 config.wsgi:application` under
NSSM or Task Scheduler ("run whether user is logged on or not"), and put IIS
or Nginx in front for TLS. Do **not** expose waitress directly to the
internet.

## Health checks

| Endpoint | Use |
| --- | --- |
| `/health/` | launcher / load balancer / Docker healthcheck |
| `/api/health` | legacy probe (`{"ok": true, "app": "StudentAttendance"}`) |
| `/api/core/health/` | Django-native probe with version and time |

Docker Compose marks `web` healthy only when `/health/` answers; `nginx`
starts after that.

## Scheduler

Period closures, SMS retries and update checks run in a background thread
started from `CoreConfig.ready()` when `START_BACKGROUND_JOBS` is true. To
avoid duplicate schedulers:

* the thread is skipped in management commands (`migrate`, `collectstatic`,
  `test`, …);
* under `runserver` only the autoreloader child starts it;
* every process tries to take `<DATA_DIR>/scheduler.lock` with a non-blocking
  OS file lock (`apps/core/runtime_lock.py`); the first one wins and the others
  stay idle. The lock is released automatically when that process exits, so a
  crashed or restarted worker is replaced without manual cleanup.
* gunicorn runs with `preload_app = False` so each worker opens its own SQLite
  connection; the file lock still guarantees exactly one scheduler. Do not run
  a second gunicorn instance against the same database.

If you prefer an external scheduler, set `ATTENDANCE_BACKGROUND_JOBS=0` so the
WSGI processes stay idle, then run the dedicated command in its own service:

```bash
python manage.py run_scheduler        # absence sweeper, updates, heartbeat
python manage.py run_scheduler --interval 30
```

It takes the same `DATA_DIR/scheduler.lock`, so a second copy exits with an
error instead of duplicating work.

## Reverse proxy

* `client_max_body_size 30m` — matches `MAX_CONTENT_LENGTH` (imports, photos).
* `proxy_read_timeout 120s` — the scanner bridge long-polls and XLSX exports
  can take longer than 60 s.
* `X-Forwarded-Proto` must be set; production enables HSTS and secure cookies.
* Nginx served `/static/` directly from the shared volume; Django's
  `apps/core/views.static_file` remains the fallback for waitress/desktop
  where no proxy exists.
* Do not cache `/api/` responses: they already send `Cache-Control: no-store`.

## Android client

`TimeTrackEnterpriseAndroid/` is the Flutter companion. For a desktop/LAN
server, start the desktop launcher on the school computer, use the printed
`http://<LAN-IP>:<PORT>` address, and keep the phone on the same reachable LAN.
The current Android manifest does not declare cleartext HTTP access. If Android
rejects that LAN URL, this build needs a reviewed app-level LAN transport
configuration or a trusted HTTPS endpoint on the school network; entering the
IP alone cannot override Android's transport policy.
For hosting, use the public HTTPS origin (for example
`https://attendance.example.org`) and include its hostname in
`ATTENDANCE_ALLOWED_HOSTS`; the Android client rejects public HTTP URLs and
redirects.

The companion uses `/api/mobile/*` for staff-code login, parent login, the
staff/parent portals, offline roster downloads, and idempotent scan uploads.
The administrator issues staff codes from **الإعدادات → المستخدمون**; a parent
uses the student's 12-digit national ID. See the mobile API section in
`docs/api/README.md` for request and authentication details.

The app also hosts a separate HTTP gateway on the phone for the desktop SMS and
scanner integrations. It is reachable from the desktop when both devices share
a LAN. A remote hosted server cannot initiate a connection to a phone's private
LAN address; hosted SMS through the phone gateway requires a VPN/tunnel or a
future outbound polling/relay flow. The parent/staff portal and scan sync do
work from Android to a hosted HTTPS server.

The separate `/api/sync/*` protocol is a different, generic data-sync feature;
it is not the authentication or roster API used by the TimeTrack companion.
Its pairing flow is:

1. **الإعدادات → المزامنة** → register a device; the token is shown once.
2. Enter the server URL and token in a client implementing `/api/sync/*`.
3. Push a change, then pull on another device or in the browser.
4. Resolve any conflict from the desktop **الإعدادات → المزامنة** screen.

The token authenticates only the sync endpoints; it never grants page access.

## Checklist

- [ ] `DEBUG = False` (production settings).
- [ ] `ATTENDANCE_SECRET_KEY` is set from a secret store and the `data/`
      volume is not world-readable.
- [ ] `ATTENDANCE_ALLOWED_HOSTS` and `ATTENDANCE_CSRF_TRUSTED_ORIGINS` match
      the public name.
- [ ] TLS terminates at Nginx/IIS; HTTP redirects to HTTPS.
- [ ] `python manage.py check --deploy --settings=config.settings.production`
      reports no warnings.
- [ ] The seeded `admin` password has been changed.
- [ ] Backups run daily and were restored once on a test machine.
- [ ] Logs rotate (`data/logs/app.log`, 2 MiB × 3).
- [ ] Devices listed under **المزامنة** are the ones that should have access.
