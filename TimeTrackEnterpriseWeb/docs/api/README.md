# API reference

Everything is mounted under `/api/`. The routes migrated from the legacy Flask
application keep the **no-trailing-slash** form (`/api/students`), so existing
clients and the bundled JavaScript keep working without redirects. The native
Django modules (`sync`, `accounts`, `core`) use a trailing slash.

`docs/api/openapi.yaml` contains a machine-readable contract for the stable
endpoints. The tables below are the complete inventory.

## Conventions

| Topic | Behaviour |
| --- | --- |
| Success | `{"ok": true, ...}` — HTTP 200/201 |
| Error | `{"ok": false, "error": {"code": "...", "message": "..."}}` |
| Encoding | UTF-8 JSON, `ensure_ascii=false` (Arabic is sent literally) |
| Digits | Arabic-Indic digits are normalised to Western digits in every response |
| Caching | `Cache-Control: no-store` on `/api/` |
| CSRF | Session mutations require `X-Requested-With: StudentAttendance` |
| Device auth | `/api/sync/*` accepts `X-Device-Token` instead of a session |
| Trailing slash | Legacy routes: no slash. Native routes: slash |

Error codes: `auth_required` (401), `forbidden` (403), `csrf` (403),
`not_found` (404), `validation` (400), `account` (400), `busy` (409),
`update` (502), `server_error` (500).

The browser session is also available to clients through
`GET /api/accounts/me/`.

## Health and core

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/health` | public | Legacy health probe (`app`, `ok`) |
| GET | `/api/core/health/` | public | Django-native probe (version, time) |
| GET | `/health/` | public | Launcher/reverse-proxy probe |
| GET | `/api/system/backup` | admin | Download a gzipped SQLite backup |
| POST | `/api/system/shutdown` | admin | Ask the desktop launcher to stop |
| GET | `/api/update/status` | admin | Last update check + staged build |
| POST | `/api/update/check` | admin | Fetch, verify and stage an update |
| POST | `/api/update/install` | admin | Install the staged signed update |

## Students

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/students` | user | Search/list (`q`, `class_group`, `active`) |
| GET | `/api/students/classes` | user | Distinct class groups + counts |
| GET | `/api/students/<nin>` | user | One student |
| POST | `/api/students` | user | Create |
| PUT | `/api/students/<nin>` | user | Update |
| POST | `/api/students/<nin>/photo` | user | Upload a photo (multipart) |
| POST | `/api/import/parse` | user | Parse XLS/XLSX/HTML and suggest a mapping |
| POST | `/api/import/preview` | user | Validate rows against the database |
| POST | `/api/import/commit` | user | Insert/update students |

## Attendance and gate

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/dashboard` | user | Today's counters and recent activity |
| GET | `/api/gate/context` | user | Open periods, classes, anti-passback setting |
| POST | `/api/gate/scan` | user | Record a scan (NIN or barcode) |
| POST | `/api/gate/regularize-absence` | user | Convert an absence to present/late |
| GET | `/api/attendance/list` | user | Daily log (`date`, `period_id`, filters) |
| GET | `/api/attendance/absence-preview` | user | Recipients before sending SMS |
| POST | `/api/attendance/close` | user | Close a period (idempotent) |
| POST | `/api/attendance/send-absences` | user | Queue absence SMS |
| POST | `/api/attendance/<log_id>/excuse` | user | Mark a log excused |
| GET/POST/PUT/DELETE | `/api/periods[/<id>]` | user / admin | Period management |

## Slips

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/entry-slip/context` | user | Reasons, periods, recent slips |
| POST | `/api/entry-slip/lookup` | user | Look up a student by NIN/QR |
| POST | `/api/entry-slip` | user | Issue an entry slip (idempotent) |
| GET | `/api/entry-slip/verify?code=` | user | Verify a printed slip |
| GET | `/api/entry-slip/<code>/qr` | user | SVG QR |
| GET | `/api/exit-slip/context` | user | Reasons, open slips |
| POST | `/api/exit-slip/lookup` | user | Look up a student |
| POST | `/api/exit-slip` | user | Issue an exit slip |
| POST | `/api/exit-slip/return` | user | Mark a slip returned |
| GET | `/api/exit-slip/verify?code=` | user | Verify a slip |
| GET | `/api/exit-slip/<code>/qr` / `barcode` | user | SVG QR / Code128 |

## Messaging

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/settings` | admin | All settings |
| PUT | `/api/settings` | admin | Validated settings update |
| POST | `/api/settings/test-sms` | admin | Send a test SMS |
| POST | `/api/settings/test-whatsapp` | admin | Validate the Cloud API template |
| GET | `/api/sms/queue` | user | Pending/failed SMS for a day |
| POST | `/api/sms/dispatch` | user | Start the SMS job |
| POST | `/api/sms/<id>/retry` | user | Retry one SMS |
| GET | `/api/sms/jobs/current` / `<id>` | user | Job progress |
| GET | `/api/messages/gateway` | admin | Phone gateway status |
| POST | `/api/messages/gateway/pair` | admin | Pair the Android gateway (PIN) |
| GET | `/api/messages/students` | user | Recipients and opt-out state |
| POST | `/api/messages/preview` | user | Render the template per student |
| POST | `/api/messages/send` | user | Send a campaign (SMS/WhatsApp/Cloud) |
| GET | `/api/messages/campaigns[/<id>]` | user | Campaign history and items |
| GET | `/api/messages/jobs/current` / `<id>` | user | Campaign job progress |

## Reports and printing

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/reports/daily` | user | Daily JSON report |
| GET | `/api/reports/monthly` | user | Monthly JSON report |
| GET | `/api/reports/daily.xlsx` | user | Daily XLSX export |
| GET | `/api/reports/monthly.xlsx` | user | Monthly XLSX export |
| PUT | `/api/print/config` | admin | Card/sticker layout and toggles |
| GET | `/api/qr/<nin>` | user | Student QR (SVG) |
| GET | `/api/barcode/<nin>` | user | Student Code128 (SVG) |
| GET | `/print/sheet` | user | Print studio page (cards/stickers) |
| GET | `/reports/print` | user | Printable report |

## Scanner bridge

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/scanner/bridge/poll` | user | Long-poll a scan from a paired phone |
| GET | `/api/scanner/phones` | user | Paired phones |
| POST | `/api/scanner/phones/pair` | user | Pair a phone |
| DELETE | `/api/scanner/phones/<id>` | user | Revoke a phone |

## Accounts

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/users` | admin | Accounts |
| POST | `/api/users` | admin | Create an account |
| PUT | `/api/users/<id>` | admin | Update role/password/state |
| DELETE | `/api/users/<id>` | admin | Delete (guarded: last admin/self) |
| POST | `/upload/<kind>` | user | Upload logo/stamp/photo |
| GET | `/assets/i18n.js` | public | Localisation catalog for the UI |
| GET | `/language/<code>?next=` | user | Switch language (sets cookie) |

## Synchronisation (native Django)

Protocol version **1**. All payloads are JSON; device requests use the token
returned by `POST /api/sync/devices/`.

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| GET | `/api/sync/capabilities/` | public | Version, entities, features |
| GET | `/api/sync/devices/` | session | List devices (admin: all, user: own) |
| POST | `/api/sync/devices/` | session | Register a device → token |
| POST | `/api/sync/devices/<uuid>/deactivate/` | admin | Revoke a token |
| POST | `/api/sync/push/` | device | Idempotent batch of changes |
| GET | `/api/sync/pull/?since=&entity=&limit=` | device | Incremental pull (excludes own changes) |
| GET | `/api/sync/conflicts/?all=1` | session/device | Pending (or all) conflicts |
| POST | `/api/sync/conflicts/<uuid>/resolve/` | admin | `local`, `server` or `merged` |

### Change object

```json
{
  "client_id": "b2f5c0a4-1a55-4f0e-9b4e-3f0f2c9a1d77",
  "entity": "student",
  "entity_key": "2099000101",
  "operation": "update",
  "base_revision": 3,
  "updated_at": "2026-10-31T08:15:00Z",
  "payload": {"first_name": "أمين"}
}
```

`entity` ∈ `student`, `period`, `attendance`, `entry_slip`, `exit_slip`,
`settings`, `message_campaign`. `operation` ∈ `create`, `update`, `delete`.

Rules:

* `client_id` is a UUID generated by the **client**; replaying it returns the
  original result with `duplicate: true`.
* `base_revision` is the `server_revision` the client edited. When the server
  holds a newer applied revision — or the client sends `create` for an existing
  key — the change is stored as `conflict` and returned with `conflict_id`.
* `pull` never returns the caller's own changes, so a client can merge safely.

```json
{
  "applied": 1, "duplicates": 0, "conflicts": 0, "rejected": 0,
  "results": [
    {"client_id": "b2f5…", "entity": "student", "entity_key": "2099000101",
     "status": "applied", "server_revision": 4, "duplicate": false}
  ]
}
```

### Pull response

```json
{
  "ok": true,
  "changes": [
    {"entity": "student", "entity_key": "2099000101", "operation": "update",
     "payload": {"first_name": "أمين"}, "server_revision": 4,
     "device": "…", "updated_at": "2026-10-31T08:15:00"}
  ],
  "count": 1,
  "server_time": "2026-10-31T08:15:01.123456",
  "next_since": "2026-10-31T08:15:01.123456"
}
```

Pass `next_since` back as `since` on the next call. It carries microseconds, so
two changes made in the same second are never skipped. When the page is full
(`count == limit`), `next_since` is the timestamp of the last returned change;
otherwise it is the server time captured before the query.

## Authentication summary

* **Browser**: `user_id` in the Django session; login is `/login`.
* **API user**: same session + `X-Requested-With: StudentAttendance` for
  mutations.
* **Device**: `X-Device-Token: <token>`; the token is validated by the sync
  endpoints and never grants page access.
* **Admin-only** prefixes: `/api/settings`, `/api/users`, `/api/uploads`,
  `/api/system/*`, `/api/update/*`, `/api/messages/gateway/pair`, and period
  mutations.
