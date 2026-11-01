"""Core constants: permission codes and audit action labels."""
from __future__ import annotations

PERMISSION_CODES = {
    "view_dashboard": "View Dashboard",
    "manage_students": "Manage Students",
    "manage_periods": "Manage Periods",
    "scan_gate": "Gate Scan",
    "close_period": "Close Period",
    "manage_attendance": "Manage Attendance",
    "send_sms": "Send SMS",
    "manage_settings": "Manage Settings",
    "manage_users": "Manage Users",
    "backup_system": "Backup System",
    "update_system": "Update System",
}

ROLE_PERMISSIONS = {
    "admin": list(PERMISSION_CODES.keys()),
    "user": [
        "view_dashboard",
        "manage_students",
        "scan_gate",
        "manage_attendance",
        "send_sms",
    ],
}

ACTION_LABELS = {
    "create": "إنشاء",
    "update": "تحديث",
    "delete": "حذف",
    "login": "تسجيل دخول",
    "logout": "تسجيل خروج",
    "backup": "نسخة احتياطية",
    "shutdown": "إغلاق النظام",
    "import": "استيراد",
    "close_period": "إغلاق فترة",
    "excuse": "تبرير غياب",
    "issue_slip": "إصدار ورقة دخول",
    "send_sms": "إرسال رسائل",
    "update_check": "فحص تحديث",
    "update_install": "تثبيت تحديث",
}