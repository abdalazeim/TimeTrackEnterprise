"""Synchronisation admin: devices, records and conflict review."""
from __future__ import annotations

from django.contrib import admin, messages

from apps.synchronization.models import Device, SyncConflict, SyncRecord
from apps.synchronization.services import SyncError, resolve_conflict


class SyncConflictInline(admin.StackedInline):
    model = SyncConflict
    extra = 0
    readonly_fields = ("server_payload", "client_payload", "created_at", "resolved_at")


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ("name", "platform", "app_version", "is_active", "created_by", "last_seen_at")
    list_filter = ("platform", "is_active")
    search_fields = ("name", "created_by")
    readonly_fields = ("token", "created_at", "last_seen_at")
    actions = ("deactivate",)

    @admin.action(description="تعطيل الأجهزة المحددة")
    def deactivate(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f"تم تعطيل {updated} جهاز.", level=messages.SUCCESS)


@admin.register(SyncRecord)
class SyncRecordAdmin(admin.ModelAdmin):
    list_display = ("entity", "entity_key", "operation", "status", "server_revision", "device", "created_at")
    list_filter = ("entity", "status", "operation")
    search_fields = ("entity_key",)
    readonly_fields = (
        "id",
        "client_id",
        "device",
        "entity",
        "entity_key",
        "operation",
        "payload",
        "base_revision",
        "server_revision",
        "status",
        "error",
        "created_at",
        "applied_at",
    )
    inlines = (SyncConflictInline,)

    def has_add_permission(self, request) -> bool:
        return False


@admin.register(SyncConflict)
class SyncConflictAdmin(admin.ModelAdmin):
    list_display = ("record", "resolution", "resolved_by", "created_at", "resolved_at")
    list_filter = ("resolution",)
    readonly_fields = (
        "record",
        "server_payload",
        "client_payload",
        "resolved_payload",
        "resolved_by",
        "resolved_at",
        "created_at",
    )
    actions = ("keep_client", "keep_server")

    def _resolve(self, request, queryset, strategy):
        done = 0
        for conflict in queryset:
            try:
                resolve_conflict(conflict, strategy, actor=request.user.username)
                done += 1
            except SyncError as error:
                self.message_user(request, str(error), level=messages.ERROR)
        self.message_user(request, f"تمت معالجة {done} تعارض.", level=messages.SUCCESS)

    @admin.action(description="اعتماد نسخة العميل")
    def keep_client(self, request, queryset):
        self._resolve(request, queryset, "local")

    @admin.action(description="اعتماد نسخة الخادم")
    def keep_server(self, request, queryset):
        self._resolve(request, queryset, "server")
