"""Backup service."""
from __future__ import annotations

import gzip
import shutil
from pathlib import Path
from typing import Any

from django.conf import settings


def create_backup(backup_path: Path) -> dict[str, Any]:
    """Create a gzip-compressed backup of the SQLite database."""
    db_path = Path(settings.DATABASES["default"]["NAME"])
    if not db_path.exists():
        raise FileNotFoundError(f"Database file not found: {db_path}")

    backup_path.parent.mkdir(parents=True, exist_ok=True)
    with open(db_path, "rb") as f_in:
        with gzip.open(backup_path, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)

    return {
        "path": str(backup_path),
        "size": backup_path.stat().st_size,
        "database": str(db_path),
    }


def restore_backup(backup_path: Path) -> None:
    """Restore a database from a gzip backup."""
    db_path = Path(settings.DATABASES["default"]["NAME"])
    with gzip.open(backup_path, "rb") as f_in:
        with open(db_path, "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)