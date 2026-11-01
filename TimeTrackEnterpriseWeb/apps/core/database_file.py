"""Database file naming and legacy-name migration helpers."""
from __future__ import annotations

import os
import sqlite3
import tempfile
from pathlib import Path

DATABASE_FILENAME = "TimeTrackEnterprise.db"
LEGACY_DATABASE_FILENAME = "attendance.db"


def default_database_path(
    data_dir: str | Path, configured: str | Path | None = None
) -> Path:
    """Return the configured database path or the branded default path."""
    if configured:
        return Path(configured).expanduser().resolve()
    return Path(data_dir).expanduser().resolve() / DATABASE_FILENAME


def migrate_legacy_database(path: str | Path) -> bool:
    """Copy the old SQLite database to the branded filename once, safely.

    SQLite's backup API includes committed WAL data. The source is retained as
    a recovery copy, and an already existing target is never overwritten.
    """
    target = Path(path).expanduser().resolve()
    if target.name.casefold() != DATABASE_FILENAME.casefold() or target.exists():
        return False

    legacy = target.with_name(LEGACY_DATABASE_FILENAME)
    if not legacy.is_file():
        return False

    target.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(
        prefix=f".{DATABASE_FILENAME}.", suffix=".migration", dir=target.parent
    )
    os.close(handle)
    temporary = Path(temporary_name)
    source_connection = None
    destination_connection = None
    try:
        source_uri = legacy.as_uri() + "?mode=rw"
        source_connection = sqlite3.connect(source_uri, uri=True, timeout=20)
        destination_connection = sqlite3.connect(str(temporary), timeout=20)
        source_connection.backup(destination_connection)
        result = destination_connection.execute("PRAGMA quick_check").fetchone()
        if not result or result[0] != "ok":
            raise sqlite3.DatabaseError("SQLite integrity check failed during database rename")
        destination_connection.close()
        destination_connection = None
        source_connection.close()
        source_connection = None

        try:
            # Same-directory hard-link creation publishes the completed file
            # atomically and fails instead of replacing a concurrent target.
            os.link(temporary, target)
        except FileExistsError:
            return False
        except OSError:
            # FAT and some network filesystems do not support hard links.
            if target.exists():
                return False
            try:
                os.rename(temporary, target)
            except FileExistsError:
                return False
        return True
    except (OSError, sqlite3.Error) as exc:
        raise RuntimeError(
            f"Could not migrate the existing database {legacy} to {target}: {exc}"
        ) from exc
    finally:
        if destination_connection is not None:
            destination_connection.close()
        if source_connection is not None:
            source_connection.close()
        temporary.unlink(missing_ok=True)
