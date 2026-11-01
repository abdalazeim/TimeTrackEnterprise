"""startmodule command: scaffold a new module under apps/modules/."""
from __future__ import annotations

from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Create a new module package under apps/modules/"

    def add_arguments(self, parser):
        parser.add_argument("name", type=str, help="Module name (e.g. attendance, messaging)")

    def handle(self, *args, **options):
        name = options["name"]
        base = f"apps/modules/{name}"
        for sub in ("models", "services", "views", "serializers", "forms", "migrations", "tests"):
            path = f"{base}/{sub}"
            import os
            os.makedirs(path, exist_ok=True)
            with open(f"{path}/__init__.py", "w", encoding="utf-8") as f:
                f.write(f"{name} {sub} package.\n")
        with open(f"{base}/apps.py", "w", encoding="utf-8") as f:
            f.write(f"""from django.apps import AppConfig


class {name.title()}Config(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.modules.{name}"
    verbose_name = "{name.title()}"
""")
        with open(f"{base}/urls.py", "w", encoding="utf-8") as f:
            f.write(f"""from django.urls import path

urlpatterns = []
""")
        self.stdout.write(self.style.SUCCESS(f"Module '{name}' created at {base}/"))