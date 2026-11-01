"""Core admin registration."""
from __future__ import annotations

from django.contrib import admin

from apps.core.models import AuditLog, SystemSetting, LookupCategory


@admin.register(SystemSetting)
class SystemSettingAdmin(admin.ModelAdmin):
    list_display = ("key", "value", "created_at", "updated_at")
    search_fields = ("key", "value")
    list_per_page = 50


@admin.register(LookupCategory)
class LookupCategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "items", "created_at")
    search_fields = ("name",)


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ("action", "user", "target_table", "target_id", "created_at")
    list_filter = ("action", "created_at")
    search_fields = ("target_table", "target_id", "detail")
    date_hierarchy = "created_at"
    list_per_page = 50