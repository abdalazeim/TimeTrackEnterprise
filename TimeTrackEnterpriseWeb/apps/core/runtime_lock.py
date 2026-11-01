"""Cross-process locks for process-wide background workers.

``CoreConfig.ready()`` runs once per process.  Under gunicorn (or any
multi-worker WSGI server) every worker imports the application, so starting the
scheduler there would create duplicate absence sweepers, update checkers and
gateway heartbeats.  A byte-range file lock solves this without stale-PID
guessing: the operating system releases the lock when the owning process exits,
including a crash.

The helpers are intentionally tiny and dependency-free.  Windows uses
``msvcrt.locking`` and POSIX uses ``fcntl.flock``.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import IO

from django.conf import settings

logger = logging.getLogger("attendance")

try:  # POSIX
    import fcntl
except ImportError:  # pragma: no cover - Windows
    fcntl = None  # type: ignore[assignment]

try:  # Windows
    import msvcrt
except ImportError:  # pragma: no cover - POSIX
    msvcrt = None  # type: ignore[assignment]


def _lock_directory() -> Path:
    data_dir = getattr(settings, "DATA_DIR", None)
    directory = Path(data_dir) if data_dir else Path(settings.BASE_DIR) / "data"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def _try_lock(handle: IO[str]) -> bool:
    if fcntl is not None:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except OSError:
            return False
    if msvcrt is not None:  # pragma: no cover - exercised on Windows only
        # ``msvcrt.locking`` locks a byte range starting at the current file
        # position; make sure the file contains at least one byte.
        handle.seek(0, 2)
        if handle.tell() == 0:
            handle.write(" ")
            handle.flush()
        handle.seek(0)
        try:
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            return True
        except OSError:
            return False
    return False


def acquire(name: str) -> IO[str] | None:
    """Try to take ``<DATA_DIR>/<name>.lock`` without blocking.

    Returns the open file handle on success (keep it alive for as long as the
    protected process runs) or ``None`` when another process owns the lock.
    """
    path = _lock_directory() / f"{name}.lock"
    try:
        handle = path.open("a+", encoding="utf-8")
    except OSError:
        logger.exception("Unable to open the %s lock file", name)
        return None
    if _try_lock(handle):
        return handle
    handle.close()
    return None
