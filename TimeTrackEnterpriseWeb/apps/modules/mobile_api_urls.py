"""Flutter gateway, staff portal and parent portal routes."""
from django.urls import path

from apps.modules import mobile_api

urlpatterns = [
    path("hello", mobile_api.hello),
    path("staff-codes", mobile_api.issue_staff_code),
    path("pair", mobile_api.pair_staff),
    path("login-code", mobile_api.login_gateway),
    path("devices/session", mobile_api.device_session),
    path("offline/roster", mobile_api.offline_roster),
    path("scans/sync", mobile_api.sync_scans),
    path("portal/dashboard", mobile_api.staff_dashboard),
    path("parent/login", mobile_api.parent_login),
    path("parent/me", mobile_api.parent_me),
    path("parent/attendance", mobile_api.parent_attendance),
    path("parent/notifications", mobile_api.parent_notifications),
    path("parent/notifications/read", mobile_api.parent_notifications_read),
]
