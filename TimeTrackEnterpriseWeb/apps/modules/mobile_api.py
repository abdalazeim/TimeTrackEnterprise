"""Native Django API for the Flutter TimeTrack Enterprise companion.

The old mobile client was extracted from an APK, so these routes implement its
documented HTTP contract while reusing the existing attendance service and the
legacy-compatible SQLite tables.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import re
import secrets
from datetime import date, datetime, timedelta

from django.conf import settings
from django.core import signing
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt

from apps.core.compat import g
from apps.core.db import get_db, get_settings, int_setting
from apps.core.utils import ValidationError, full_name, normalize_nin
from apps.modules.services import attendance_service as attendance

TOKEN_SALT = "timetrack-enterprise-mobile-v1"
TOKEN_MAX_AGE = 30 * 24 * 60 * 60
LOGIN_WINDOW = 15 * 60
LOGIN_LIMIT = 10
MAX_SCAN_BATCH = 300
STAFF_CODE_RE = re.compile(r"^[0-9]{8}$")
PARENT_CODE_RE = re.compile(r"^[0-9]{12}$")


def _json(data: dict, status: int = 200) -> JsonResponse:
    return JsonResponse(data, status=status, json_dumps_params={"ensure_ascii": False})


def _ok(**payload) -> JsonResponse:
    return _json({"ok": True, **payload})


def _error(code: str, message: str, status: int = 400, **extra) -> JsonResponse:
    body = {"ok": False, "error": {"code": code, "message": message}}
    body.update(extra)
    return _json(body, status)


def _body(request) -> dict:
    try:
        value = json.loads(request.body or b"{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _method(request, method: str) -> JsonResponse | None:
    if request.method != method:
        return _error("method_not_allowed", "طريقة الطلب غير مسموح بها.", 405)
    return None


def _now() -> datetime:
    return datetime.now()


def _now_text() -> str:
    return _now().isoformat(timespec="seconds")


def _keyed_hash(value: str, namespace: str) -> str:
    secret = str(settings.SECRET_KEY).encode("utf-8")
    message = f"timetrack-mobile:{namespace}:{value}".encode("utf-8")
    return hmac.new(secret, message, hashlib.sha256).hexdigest()


def _issue_token(kind: str, **claims) -> str:
    payload = {"kind": kind, "iat": int(_now().timestamp()), **claims}
    return signing.dumps(payload, salt=TOKEN_SALT, compress=True)


def _token(request, allowed: set[str] | None = None) -> dict | None:
    header = request.META.get("HTTP_AUTHORIZATION", "")
    if not header.lower().startswith("bearer "):
        return None
    raw = header[7:].strip()
    if not raw:
        return None
    try:
        payload = signing.loads(raw, salt=TOKEN_SALT, max_age=TOKEN_MAX_AGE)
    except signing.BadSignature:
        return None
    if not isinstance(payload, dict) or (allowed and payload.get("kind") not in allowed):
        return None
    return payload


def _server_info(conn) -> dict:
    values = get_settings(conn)
    return {
        "school_name": values.get("school_name", ""),
        "academic_year": values.get("academic_year", ""),
    }


def _public_user(row) -> dict:
    # The Flutter role matcher follows the existing user API contract:
    # administrators are "admin" and staff accounts are "user".
    role = row["role"]
    label = "مدير" if role == "admin" else "موظف"
    return {
        "id": row["id"],
        "username": row["username"],
        "display_name": row["display_name"] or row["username"],
        "role": role,
        "role_label": label,
    }


def _client_address(request) -> str:
    # Do not trust forwarded headers here: this is a LAN application and the
    # login limiter must not be bypassable by supplying X-Forwarded-For.
    return request.META.get("REMOTE_ADDR", "unknown") or "unknown"


def _allow_login_attempt(conn, scope: str, address: str) -> bool:
    now = _now()
    address_hash = _keyed_hash(address, f"rate:{scope}")
    row = conn.execute(
        "SELECT attempts, window_started_at FROM mobile_login_attempts WHERE scope = ? AND address_hash = ?",
        (scope, address_hash),
    ).fetchone()
    if row:
        try:
            started = datetime.fromisoformat(row["window_started_at"])
        except ValueError:
            started = now - timedelta(seconds=LOGIN_WINDOW + 1)
        if (now - started).total_seconds() < LOGIN_WINDOW:
            if int(row["attempts"]) >= LOGIN_LIMIT:
                return False
            with conn:
                conn.execute(
                    "UPDATE mobile_login_attempts SET attempts = attempts + 1, updated_at = ? WHERE scope = ? AND address_hash = ?",
                    (_now_text(), scope, address_hash),
                )
            return True
    with conn:
        conn.execute(
            """INSERT INTO mobile_login_attempts(scope, address_hash, attempts, window_started_at, updated_at)
               VALUES(?, ?, 1, ?, ?)
               ON CONFLICT(scope, address_hash) DO UPDATE SET attempts = 1,
                 window_started_at = excluded.window_started_at, updated_at = excluded.updated_at""",
            (scope, address_hash, _now_text(), _now_text()),
        )
    return True


def _rate_limited() -> JsonResponse:
    response = _error("rate_limited", "محاولات كثيرة. انتظر 15 دقيقة ثم أعد المحاولة.", 429)
    response["Retry-After"] = str(LOGIN_WINDOW)
    return response


def _staff_by_code(conn, code: str):
    if not STAFF_CODE_RE.fullmatch(code):
        return None
    hashed = _keyed_hash(code, "staff-code")
    row = conn.execute(
        """SELECT u.*, c.id AS mobile_code_id
           FROM mobile_staff_codes c JOIN users u ON u.id = c.user_id
           WHERE c.code_hash = ? AND c.revoked_at IS NULL AND c.expires_at > ?
             AND u.is_active = 1 LIMIT 1""",
        (hashed, _now_text()),
    ).fetchone()
    return row


def _request_staff(request, allowed: set[str] | None = None):
    payload = _token(request, {"staff", "device"})
    if not payload or (allowed and payload.get("kind") not in allowed):
        return None
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE id = ? AND is_active = 1",
        (payload.get("user_id"),),
    ).fetchone()
    if not user:
        return None
    if payload.get("kind") == "device":
        device = conn.execute(
            "SELECT status FROM mobile_devices WHERE device_id = ? AND user_id = ?",
            (payload.get("device_id"), user["id"]),
        ).fetchone()
        if not device or device["status"] != "approved":
            return None
    return payload, user


def _request_parent(request):
    payload = _token(request, {"parent"})
    if not payload:
        return None
    conn = get_db()
    row = conn.execute(
        "SELECT * FROM students WHERE student_nin = ? AND is_active = 1",
        (payload.get("student_nin"),),
    ).fetchone()
    return (payload, row) if row else None


def _issue_mobile_session(user, kind: str, device_id: str = "") -> str:
    return _issue_token(kind, user_id=user["id"], device_id=device_id)


@csrf_exempt
def hello(request):
    if response := _method(request, "POST"):
        return response
    data = _body(request)
    device_id = str(data.get("device_id", "")).strip()
    if not device_id or len(device_id) > 128:
        return _error("invalid_device", "معرّف الجهاز غير صالح.")
    return _ok(registered=True, server=_server_info(get_db()))


@csrf_exempt
def issue_staff_code(request):
    if response := _method(request, "POST"):
        return response
    admin = g.get("user")
    if not admin or admin.get("role") != "admin":
        return _error("forbidden", "يجب تسجيل الدخول كمدير لإصدار رمز موظف.", 403)
    if request.headers.get("X-Requested-With") != "StudentAttendance":
        return _error("request_rejected", "تعذر التحقق من مصدر الطلب.", 403)
    data = _body(request)
    try:
        user_id = int(data.get("user_id"))
    except (TypeError, ValueError):
        return _error("invalid_user", "اختر حساب الموظف أولًا.")
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE id = ? AND is_active = 1", (user_id,)
    ).fetchone()
    if not user:
        return _error("user_not_found", "حساب المستخدم غير موجود أو غير نشط.", 404)
    code = f"{secrets.randbelow(100_000_000):08d}"
    now = _now_text()
    expires = (_now() + timedelta(days=365)).isoformat(timespec="seconds")
    with conn:
        conn.execute(
            "UPDATE mobile_staff_codes SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL",
            (now, user_id),
        )
        conn.execute(
            """INSERT INTO mobile_staff_codes(user_id, code_hash, issued_by, created_at, expires_at)
               VALUES(?, ?, ?, ?, ?)""",
            (user_id, _keyed_hash(code, "staff-code"), admin["id"], now, expires),
        )
    return _ok(
        code=code,
        expires_at=expires,
        user=_public_user(user),
        message="احفظ الرمز الآن وشاركه مع الموظف؛ لن يظهر كاملًا مرة أخرى.",
    )


@csrf_exempt
def pair_staff(request):
    if response := _method(request, "POST"):
        return response
    data = _body(request)
    conn = get_db()
    if not _allow_login_attempt(conn, "staff", _client_address(request)):
        return _rate_limited()
    role = str(data.get("role", "")).strip().lower()
    if role not in {"admin", "employee"}:
        return _error("invalid_role", "الدور المحدد غير صالح.")
    code = str(data.get("code", "")).strip()
    user = _staff_by_code(conn, code)
    if not user:
        return _error("invalid_code", "رمز الموظف غير صحيح أو منتهي الصلاحية.", 401)
    expected_role = "admin" if user["role"] == "admin" else "employee"
    if role != expected_role:
        return _error("role_mismatch", "الدور المحدد لا يطابق حساب المستخدم.", 403)
    return _ok(
        token=_issue_mobile_session(user, "staff", str(data.get("device_id", ""))[:128]),
        user=_public_user(user),
        server=_server_info(conn),
    )


@csrf_exempt
def login_gateway(request):
    if response := _method(request, "POST"):
        return response
    data = _body(request)
    conn = get_db()
    if not _allow_login_attempt(conn, "staff", _client_address(request)):
        return _rate_limited()
    code = str(data.get("passcode", "")).strip()
    user = _staff_by_code(conn, code)
    if not user:
        return _error("invalid_code", "رمز الموظف غير صحيح أو منتهي الصلاحية.", 401)
    device_id = str(data.get("device_id", "")).strip()
    if not device_id or len(device_id) > 128:
        return _error("invalid_device", "معرّف الجهاز غير صالح.")
    secret = secrets.token_urlsafe(48)
    device_name = str(data.get("device_name", ""))[:120]
    platform = str(data.get("platform", ""))[:40]
    app_version = str(data.get("app_version", ""))[:40]
    now = _now_text()
    with conn:
        conn.execute(
            """INSERT INTO mobile_devices
               (device_id, user_id, device_name, platform, app_version, secret_hash, status, created_at, last_seen_at)
               VALUES(?, ?, ?, ?, ?, ?, 'approved', ?, ?)
               ON CONFLICT(device_id) DO UPDATE SET user_id = excluded.user_id,
                 device_name = excluded.device_name, platform = excluded.platform,
                 app_version = excluded.app_version, secret_hash = excluded.secret_hash,
                 status = 'approved', created_at = excluded.created_at, last_seen_at = excluded.last_seen_at""",
            (device_id, user["id"], device_name, platform, app_version,
             _keyed_hash(secret, "device-secret"), now, now),
        )
    mobile_user = _public_user(user)
    return _ok(
        token=_issue_mobile_session(user, "device", device_id),
        device_secret=secret,
        device={"name": device_name, "status": "approved", "pair_code": ""},
        user=mobile_user,
        server=_server_info(conn),
        approval_required=False,
    )


@csrf_exempt
def device_session(request):
    if response := _method(request, "POST"):
        return response
    data = _body(request)
    device_id = str(data.get("device_id", "")).strip()
    secret = str(data.get("secret", "")).strip()
    if not device_id or not secret:
        return _error("device_unknown", "جلسة الجهاز غير معروفة.", 401)
    conn = get_db()
    row = conn.execute(
        """SELECT d.*, u.* FROM mobile_devices d JOIN users u ON u.id = d.user_id
           WHERE d.device_id = ? AND u.is_active = 1""",
        (device_id,),
    ).fetchone()
    if not row:
        return _error("device_unknown", "الجهاز غير مسجل على هذا الخادم.", 401)
    if row["status"] == "blocked":
        return _error("device_blocked", "تم إيقاف هذا الجهاز من الخادم.", 403,
                      device={"name": row["device_name"], "status": "blocked"})
    expected = _keyed_hash(secret, "device-secret")
    if not hmac.compare_digest(expected, row["secret_hash"]):
        return _error("device_unknown", "بيانات جلسة الجهاز غير صحيحة.", 401)
    now = _now_text()
    with conn:
        conn.execute(
            "UPDATE mobile_devices SET last_seen_at = ?, device_name = ?, app_version = ? WHERE device_id = ?",
            (now, str(data.get("device_name", row["device_name"]))[:120],
             str(data.get("app_version", row["app_version"]))[:40], device_id),
        )
    user = conn.execute("SELECT * FROM users WHERE id = ?", (row["user_id"],)).fetchone()
    return _ok(
        token=_issue_mobile_session(user, "device", device_id),
        device={"name": row["device_name"], "status": "approved"},
        user=_public_user(user),
        server=_server_info(conn),
    )


@csrf_exempt
def offline_roster(request):
    if response := _method(request, "GET"):
        return response
    session = _request_staff(request, {"device"})
    if not session:
        return _error("auth_required", "سجل دخول جهاز البوابة أولًا.", 401)
    conn = get_db()
    students_meta = conn.execute(
        "SELECT COUNT(*) AS total, COALESCE(MAX(updated_at), '') AS latest FROM students WHERE is_active = 1"
    ).fetchone()
    periods_meta = conn.execute(
        "SELECT COUNT(*) AS total, COALESCE(MAX(updated_at), '') AS latest FROM periods WHERE is_active = 1"
    ).fetchone()
    server_info = _server_info(conn)
    raw_version = (
        f"{students_meta['total']}:{students_meta['latest']}|"
        f"{periods_meta['total']}:{periods_meta['latest']}|"
        f"{server_info['school_name']}|{server_info['academic_year']}"
    )
    version = hashlib.sha256(raw_version.encode("utf-8")).hexdigest()[:24]
    unchanged = request.GET.get("since", "") == version
    payload = {
        "version": version,
        "unchanged": unchanged,
        "server_date": date.today().isoformat(),
        **server_info,
    }
    if not unchanged:
        students = conn.execute(
            """SELECT student_nin, first_name, last_name, class_group, is_active
               FROM students WHERE is_active = 1 ORDER BY class_group, last_name, first_name"""
        ).fetchall()
        periods = conn.execute(
            """SELECT id, period_name, start_time, on_time_cutoff, absent_cutoff_time, sort_order
               FROM periods WHERE is_active = 1 ORDER BY sort_order, start_time, id"""
        ).fetchall()
        payload["students"] = [
            {"student_nin": row["student_nin"], "first_name": row["first_name"],
             "last_name": row["last_name"], "full_name": full_name(row["first_name"], row["last_name"]),
             "class_group": row["class_group"], "is_active": bool(row["is_active"])}
            for row in students
        ]
        payload["periods"] = [
            {"id": row["id"], "name": row["period_name"], "start_time": row["start_time"],
             "on_time_cutoff": row["on_time_cutoff"], "absent_cutoff_time": row["absent_cutoff_time"],
             "sort_order": row["sort_order"]}
            for row in periods
        ]
    return _ok(**payload)


def _scan_datetime(raw) -> datetime:
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("timestamp required")
    value = datetime.fromisoformat(raw.strip().replace("Z", "+00:00"))
    if timezone.is_aware(value):
        value = value.astimezone().replace(tzinfo=None)
    now = _now()
    if value > now + timedelta(minutes=5) or value < now - timedelta(days=14):
        raise ValueError("timestamp out of accepted range")
    return value


def _scan_public(result: dict) -> dict:
    attendance_row = result.get("attendance")
    if attendance_row:
        attendance_row = dict(attendance_row)
        attendance_row["status"] = str(attendance_row.get("status", "")).lower()
    raw_student = result.get("student")
    student = None
    if raw_student:
        student = {
            key: raw_student.get(key)
            for key in ("student_nin", "first_name", "last_name", "full_name", "class_group", "is_active")
        }
    return {
        "action": result.get("action", "rejected"),
        "message": result.get("message", "تعذر تسجيل المسح."),
        "student": student,
        "attendance": attendance_row,
    }


@csrf_exempt
def sync_scans(request):
    if response := _method(request, "POST"):
        return response
    session = _request_staff(request, {"device"})
    if not session:
        return _error("auth_required", "جلسة جهاز البوابة غير صالحة.", 401)
    payload = _body(request)
    scans = payload.get("scans")
    if not isinstance(scans, list) or len(scans) > MAX_SCAN_BATCH:
        return _error("invalid_batch", f"يجب إرسال دفعة لا تتجاوز {MAX_SCAN_BATCH} مسحًا.")
    token, user = session
    device_id = str(payload.get("device_id", token.get("device_id", "")))[:128]
    if not device_id or device_id != token.get("device_id"):
        return _error("invalid_device", "معرّف الجهاز لا يطابق الجلسة.", 403)
    conn = get_db()
    settings_map = get_settings(conn)
    processed = duplicates = rejected = 0
    results = []
    for item in scans:
        if not isinstance(item, dict):
            rejected += 1
            continue
        client_id = str(item.get("client_id", "")).strip()[:128]
        if not client_id:
            rejected += 1
            continue
        previous = conn.execute(
            "SELECT result_json FROM mobile_scan_receipts WHERE device_id = ? AND client_id = ?",
            (device_id, client_id),
        ).fetchone()
        if previous:
            try:
                saved = json.loads(previous["result_json"])
            except (TypeError, json.JSONDecodeError):
                saved = {"action": "duplicate", "message": "تمت معالجة هذا المسح مسبقًا.",
                         "student": None, "attendance": None}
            saved["client_id"] = client_id
            results.append(saved)
            duplicates += 1
            continue
        raw_code = str(item.get("code", "")).strip()
        if not raw_code or len(raw_code) > 128:
            result = {"action": "invalid", "message": "رمز التلميذ فارغ أو غير صالح.",
                      "student": None, "attendance": None}
            rejected += 1
        else:
            try:
                scanned_at = _scan_datetime(item.get("at"))
                result = attendance.scan_student(
                    conn,
                    raw_code,
                    period_id=item.get("period_id"),
                    now=scanned_at,
                    anti_passback_minutes=int_setting(settings_map, "anti_passback_minutes", 5, 1, 60),
                    school_weekdays=settings_map.get("school_weekdays", "0,1,2,3,4"),
                )
                attendance_data = result.get("attendance")
                if attendance_data and result.get("success"):
                    log_id = attendance_data.get("id")
                    with conn:
                        conn.execute(
                            "UPDATE attendance_logs SET source = 'MOBILE' WHERE id = ?",
                            (log_id,),
                        )
                    updated = conn.execute(
                        "SELECT * FROM attendance_logs WHERE id = ?", (log_id,)
                    ).fetchone()
                    if updated:
                        result["attendance"] = attendance.attendance_public(updated)
                public = _scan_public(result)
                if result.get("success"):
                    processed += 1
                elif result.get("action") in {"duplicate", "already_recorded", "excused"}:
                    duplicates += 1
                else:
                    rejected += 1
                result = public
            except (ValueError, TypeError, ValidationError) as exc:
                result = {"action": "invalid", "message": str(exc) or "تاريخ المسح غير صالح.",
                          "student": None, "attendance": None}
                rejected += 1
        result["client_id"] = client_id
        results.append(result)
        with conn:
            conn.execute(
                """INSERT OR IGNORE INTO mobile_scan_receipts(device_id, client_id, result_json)
                   VALUES(?, ?, ?)""",
                (device_id, client_id, json.dumps(result, ensure_ascii=False)),
            )
    now = _now()
    return _ok(
        summary={"processed": processed, "duplicates": duplicates, "rejected": rejected},
        results=results,
        server_date=now.date().isoformat(),
        server_time=now.strftime("%H:%M:%S"),
    )


@csrf_exempt
def staff_dashboard(request):
    if response := _method(request, "GET"):
        return response
    session = _request_staff(request)
    if not session:
        return _error("auth_required", "سجل الدخول إلى بوابة الموظف أولًا.", 401)
    conn = get_db()
    today = date.today().isoformat()
    totals = conn.execute(
        """SELECT COUNT(*) AS total,
                  SUM(CASE WHEN status IN ('PRESENT', 'LATE') THEN 1 ELSE 0 END) AS attended,
                  SUM(CASE WHEN status = 'ABSENT' THEN 1 ELSE 0 END) AS absent,
                  SUM(CASE WHEN status = 'LATE' THEN 1 ELSE 0 END) AS late
           FROM attendance_logs WHERE attendance_date = ?""", (today,)
    ).fetchone()
    students_count = conn.execute("SELECT COUNT(*) FROM students WHERE is_active = 1").fetchone()[0]
    latest = conn.execute(
        """SELECT a.id, a.attendance_date, a.scan_time, a.status, s.student_nin,
                  s.first_name, s.last_name, s.class_group, p.period_name
           FROM attendance_logs a JOIN students s ON s.student_nin = a.student_nin
           JOIN periods p ON p.id = a.period_id
           ORDER BY a.attendance_date DESC, a.id DESC LIMIT 20"""
    ).fetchall()
    dashboard = {
        "date": today,
        "school_name": _server_info(conn)["school_name"],
        "active_students": students_count,
        "attendance_today": int(totals["attended"] or 0),
        "absent_today": int(totals["absent"] or 0),
        "late_today": int(totals["late"] or 0),
        "records_today": int(totals["total"] or 0),
        "recent_attendance": [
            {"id": row["id"], "student_nin": row["student_nin"],
             "student_name": full_name(row["first_name"], row["last_name"]),
             "class_group": row["class_group"], "period": row["period_name"],
             "date": row["attendance_date"], "time": row["scan_time"],
             "status": str(row["status"]).lower()}
            for row in latest
        ],
    }
    return _ok(dashboard=dashboard)


@csrf_exempt
def parent_login(request):
    if response := _method(request, "POST"):
        return response
    data = _body(request)
    nin = normalize_nin(data.get("code", ""))
    if not PARENT_CODE_RE.fullmatch(nin):
        return _error("invalid_code", "رقم الطالب الوطني يجب أن يتكون من 12 رقمًا.")
    conn = get_db()
    if not _allow_login_attempt(conn, "parent", _client_address(request)):
        return _rate_limited()
    student = conn.execute(
        "SELECT * FROM students WHERE student_nin = ? AND is_active = 1", (nin,)
    ).fetchone()
    if not student:
        return _error("invalid_code", "لم يتم العثور على طالب نشط بهذا الرقم الوطني.", 401)
    parent = {
        "student_nin": student["student_nin"],
        "full_name": full_name(student["first_name"], student["last_name"]),
        "class_group": student["class_group"],
    }
    return _ok(
        token=_issue_token("parent", student_nin=student["student_nin"],
                           device_id=str(data.get("device_id", ""))[:128]),
        parent=parent,
        server=_server_info(conn),
    )


@csrf_exempt
def parent_me(request):
    if response := _method(request, "GET"):
        return response
    session = _request_parent(request)
    if not session:
        return _error("auth_required", "سجل الدخول برقم الطالب الوطني أولًا.", 401)
    _, student = session
    return _ok(parent={
        "student_nin": student["student_nin"],
        "full_name": full_name(student["first_name"], student["last_name"]),
        "class_group": student["class_group"],
        "school_name": get_settings(get_db()).get("school_name", ""),
    })


@csrf_exempt
def parent_attendance(request):
    if response := _method(request, "GET"):
        return response
    session = _request_parent(request)
    if not session:
        return _error("auth_required", "سجل الدخول برقم الطالب الوطني أولًا.", 401)
    _, student = session
    try:
        days = max(1, min(365, int(request.GET.get("days", "30"))))
    except ValueError:
        days = 30
    conn = get_db()
    rows = conn.execute(
        """SELECT a.id, a.attendance_date, a.scan_time, a.status, a.note, a.source,
                  p.period_name
           FROM attendance_logs a JOIN periods p ON p.id = a.period_id
           WHERE a.student_nin = ? AND a.attendance_date >= date('now', 'localtime', ?)
           ORDER BY a.attendance_date DESC, p.sort_order, a.id DESC LIMIT 500""",
        (student["student_nin"], f"-{days} days"),
    ).fetchall()
    items = [
        {"id": row["id"], "date": row["attendance_date"], "attendance_date": row["attendance_date"],
         "time": row["scan_time"], "scan_time": row["scan_time"],
         "period": row["period_name"], "period_name": row["period_name"],
         "status": str(row["status"]).lower(),
         "status_label": {"PRESENT": "حاضر", "LATE": "متأخر", "ABSENT": "غائب", "EXCUSED": "غياب مبرر"}.get(row["status"], row["status"]),
         "note": row["note"] or "", "source": row["source"]}
        for row in rows
    ]
    return _ok(attendance=items, days=days, student_nin=student["student_nin"])


@csrf_exempt
def parent_notifications(request):
    if response := _method(request, "GET"):
        return response
    session = _request_parent(request)
    if not session:
        return _error("auth_required", "سجل الدخول برقم الطالب الوطني أولًا.", 401)
    _, student = session
    try:
        since_id = max(0, int(request.GET.get("since_id", "0")))
    except ValueError:
        since_id = 0
    conn = get_db()
    rows = conn.execute(
        """SELECT a.id, a.attendance_date, a.scan_time, a.status, p.period_name
           FROM attendance_logs a JOIN periods p ON p.id = a.period_id
           LEFT JOIN mobile_parent_notification_reads r
             ON r.student_nin = a.student_nin AND r.attendance_id = a.id
           WHERE a.student_nin = ? AND a.id > ? AND r.attendance_id IS NULL
           ORDER BY a.id DESC LIMIT 100""",
        (student["student_nin"], since_id),
    ).fetchall()
    items = []
    labels = {"PRESENT": "حاضر", "LATE": "متأخر", "ABSENT": "غائب", "EXCUSED": "غياب مبرر"}
    for row in rows:
        status = row["status"]
        absent = status == "ABSENT"
        status_label = labels.get(status, status)
        message = (
            f"تم تسجيل غياب الطالب عن {row['period_name']} بتاريخ {row['attendance_date']}"
            if absent else
            f"تم تسجيل حالة الطالب ({status_label}) عن {row['period_name']} بتاريخ {row['attendance_date']}"
        )
        items.append({
            "id": row["id"],
            "title": "إشعار غياب" if absent else "تحديث الحضور",
            "message": message,
            "date": row["attendance_date"],
            "created_at": row["attendance_date"] + (f"T{row['scan_time']}" if row["scan_time"] else ""),
            "status": str(status).lower(),
            "status_label": status_label,
            "is_read": False,
        })
    return _ok(notifications=items, cursor=max([since_id, *[row["id"] for row in rows]]))


@csrf_exempt
def parent_notifications_read(request):
    if response := _method(request, "POST"):
        return response
    session = _request_parent(request)
    if not session:
        return _error("auth_required", "سجل الدخول برقم الطالب الوطني أولًا.", 401)
    _, student = session
    ids = _body(request).get("ids", [])
    if not isinstance(ids, list):
        return _error("invalid_ids", "قائمة الإشعارات غير صالحة.")
    safe_ids = []
    for item in ids[:200]:
        try:
            identifier = int(item)
        except (TypeError, ValueError):
            continue
        if identifier > 0:
            safe_ids.append(identifier)
    if safe_ids:
        conn = get_db()
        placeholders = ",".join("?" for _ in safe_ids)
        with conn:
            conn.execute(
                f"""INSERT OR IGNORE INTO mobile_parent_notification_reads(student_nin, attendance_id)
                    SELECT student_nin, id FROM attendance_logs
                    WHERE student_nin = ? AND id IN ({placeholders})""",
                [student["student_nin"], *safe_ids],
            )
    return _ok(marked=len(safe_ids))
