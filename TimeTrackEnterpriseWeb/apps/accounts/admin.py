"""Admin registrations for the legacy-backed user model."""
from __future__ import annotations

from django.contrib import admin

from apps.accounts.models import User
from apps.accounts.services import AccountError, update_user


@admin.register(User)
class LegacyUserAdmin(admin.ModelAdmin):
    list_display = ("username", "display_name", "role", "is_active", "last_login")
    list_filter = ("role", "is_active")
    search_fields = ("username", "display_name")
    ordering = ("username",)
    readonly_fields = ("created_at", "updated_at", "last_login")
    actions = ("deactivate",)

    def has_add_permission(self, request) -> bool:
        # Account creation must go through the application form so the
        # Werkzeug password hash and the validation rules are reused.
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return request.user.is_superuser

    @admin.action(description="تعطيل الحسابات المحددة")
    def deactivate(self, request, queryset):
        for user in queryset:
            try:
                update_user(
                    user.pk,
                    user.display_name,
                    user.role,
                    is_active=False,
                    acting_user_id=request.user.pk,
                )
            except AccountError as error:
                self.message_user(request, str(error), level="error")
