"""Restore a database backup created by ``scripts/backup.py``.

Usage::

    python scripts/restore.py backups/TimeTrackEnterprise-20261031-120000.db
    python scripts/restore.py backup.db --data-dir D:\\school-data --force

The current database is copied to ``backups/pre-restore-<timestamp>.db``
before being replaced.  Stop the application (or the desktop launcher) first;
SQLite does not allow replacing a file while it is open on Windows.
"""
from __future__ import annotations

import argparse
import os
import shutil
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from apps.core.database_file import (  # noqa: E402
    default_database_path,
    migrate_legacy_database,
)


def project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def data_dir(override: str | None) -> Path:
    if override:
        return Path(override).resolve()
    return Path(os.environ.get("ATTENDANCE_DATA_DIR") or (project_root() / "data"))


def validate(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"Backup not found: {path}")
    try:
        with sqlite3.connect(path) as connection:
            result = connection.execute("PRAGMA integrity_check").fetchone()
    except sqlite3.DatabaseError as exc:
        raise SystemExit(f"Not a SQLite database: {exc}") from exc
    if not result or result[0] != "ok":
        raise SystemExit(f"Integrity check failed: {result[0] if result else 'unknown'}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Restore a TimeTrackEnterprise database")
    parser.add_argument("backup", help="Path to the .db backup")
    parser.add_argument("--data-dir", default=None)
    parser.add_argument("--force", action="store_true", help="Replace without asking")
    args = parser.parse_args(argv)

    source = Path(args.backup).resolve()
    validate(source)

    target_dir = data_dir(args.data_dir)
    target = default_database_path(target_dir, os.environ.get("ATTENDANCE_DB_PATH"))
    target_dir.mkdir(parents=True, exist_ok=True)
    migrate_legacy_database(target)

    if target.exists():
        if not args.force:
            answer = input(f"Replace {target}? [y/N] ").strip().lower()
            if answer not in {"y", "yes"}:
                print("Cancelled.")
                return 1
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        safety = project_root() / "backups" / f"pre-restore-{stamp}.db"
        safety.parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(target) as old, sqlite3.connect(safety) as new:
            old.backup(new)
        print(f"Previous database saved to {safety}")

    shutil.copy2(source, target)
    for suffix in ("-wal", "-shm"):
        target.with_name(target.name + suffix).unlink(missing_ok=True)
    print(f"Restored {source} -> {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
