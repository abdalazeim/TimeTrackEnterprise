"""Create a timestamped backup of the SQLite database and runtime data.

Usage::

    python scripts/backup.py
    python scripts/backup.py --output D:\\backups --keep 14

The database is copied with SQLite's online backup API, so the application may
keep running.  Photos, uploads and the update staging folder are archived next
to it (``*.zip``) unless ``--db-only`` is passed.
"""
from __future__ import annotations

import argparse
import os
import shutil
import sqlite3
import sys
import zipfile
from datetime import datetime
from pathlib import Path


def project_root() -> Path:
    return Path(__file__).resolve().parent.parent


def database_path() -> Path:
    configured = os.environ.get("ATTENDANCE_DB_PATH")
    if configured:
        return Path(configured)
    data_dir = Path(os.environ.get("ATTENDANCE_DATA_DIR") or (project_root() / "data"))
    return data_dir / "attendance.db"


def copy_database(source: Path, destination: Path) -> None:
    if not source.is_file():
        raise SystemExit(f"Database not found: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(source) as src, sqlite3.connect(destination) as dst:
        src.backup(dst)


def archive_runtime(data_dir: Path, destination: Path) -> None:
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for folder in ("photos", "uploads"):
            base = data_dir / folder
            if not base.is_dir():
                continue
            for path in base.rglob("*"):
                if path.is_file():
                    archive.write(path, path.relative_to(data_dir))


def prune(output: Path, keep: int) -> None:
    if keep <= 0:
        return
    backups = sorted(output.glob("attendance-*"), key=lambda item: item.stat().st_mtime)
    for old in backups[:-keep]:
        if old.is_dir():
            shutil.rmtree(old, ignore_errors=True)
        else:
            old.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Back up the attendance database")
    parser.add_argument("--output", default=None, help="Destination folder")
    parser.add_argument("--keep", type=int, default=14, help="Backups to retain (0 = all)")
    parser.add_argument("--db-only", action="store_true", help="Skip photos/uploads")
    args = parser.parse_args(argv)

    data_dir = database_path().parent
    output = Path(args.output or (project_root() / "backups")).resolve()
    output.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    database_copy = output / f"attendance-{stamp}.db"
    copy_database(database_path(), database_copy)
    print(f"Database: {database_copy}")

    if not args.db_only:
        archive = output / f"attendance-{stamp}.zip"
        archive_runtime(data_dir, archive)
        print(f"Runtime data: {archive}")

    prune(output, args.keep)
    return 0


if __name__ == "__main__":
    sys.exit(main())
