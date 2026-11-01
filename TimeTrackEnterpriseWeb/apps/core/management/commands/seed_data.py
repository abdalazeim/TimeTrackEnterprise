"""seed_data command: seed periods and default settings."""
from __future__ import annotations

from django.core.management.base import BaseCommand

from apps.core.models import SystemSetting


class Command(BaseCommand):
    help = "Seed default periods and system settings"

    def handle(self, *args, **options):
        defaults = {
            "school_name": "اسم المؤسسة التعليمية",
            "academic_year": "2026/2027",
            "sms_test_mode": "1",
            "auto_sweep": "1",
            "anti_passback_minutes": "5",
            "color_theme": "emerald",
        }
        created = 0
        for key, value in defaults.items():
            _, was_created = SystemSetting.objects.update_or_create(
                key=key, defaults={"value": value}
            )
            if was_created:
                created += 1
        self.stdout.write(self.style.SUCCESS(f"Seeded {created} default settings."))