"""backup_db command: create a database backup."""
from __future__ import annotations

from django.core.management.base import BaseCommand

from apps.core.services.backup import create_backup
from pathlib import Path


class Command(BaseCommand):
    help = "Create a gzip backup of the attendance database"

    def add_arguments(self, parser):
        parser.add_argument(
            "--output",
            type=str,
            default="data/backups/attendance_backup.gz",
            help="Output backup path",
        )

    def handle(self, *args, **options):
        output = Path(options["output"])
        result = create_backup(output)
        self.stdout.write(
            self.style.SUCCESS(
                f"Backup created: {result['path']} ({result['size']} bytes)"
            )
        )