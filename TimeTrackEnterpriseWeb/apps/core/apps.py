"""Core app configuration and runtime bootstrap."""
from __future__ import annotations

import logging
import os
import sys

from django.apps import AppConfig
from django.conf import settings

logger = logging.getLogger("attendance")

# Management commands that must never start the background workers.
_COMMANDS_WITHOUT_WORKERS = {
    "check",
    "collectstatic",
    "compilemessages",
    "createsuperuser",
    "dbshell",
    "dumpdata",
    "flush",
    "inspectdb",
    "loaddata",
    "makemessages",
    "makemigrations",
    "migrate",
    "run_scheduler",
    "sendtestemail",
    "shell",
    "showmigrations",
    "sqlflush",
    "test",
}


class CoreConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.core"
    verbose_name = "Core"

    def ready(self) -> None:  # pragma: no cover - bootstrap side effects
        self._prepare_runtime()
        if self._should_start_workers():
            self._start_workers()

    # -- helpers -------------------------------------------------------
    @staticmethod
    def _sqlite_backend() -> bool:
        engine = settings.DATABASES.get("default", {}).get("ENGINE", "")
        return engine.endswith("sqlite3")

    def _prepare_runtime(self) -> None:
        """Create the legacy-compatible schema and runtime folders.

        Django migrations own the ORM tables while ``apps.core.db`` owns the
        legacy tables.  Creating them here keeps a fresh checkout usable even
        before the first ``migrate`` (the desktop build runs without an
        administrator).
        """
        if not self._sqlite_backend():
            return
        if not getattr(settings, "TESTING", False):
            from apps.core.database_file import migrate_legacy_database

            migrate_legacy_database(settings.DB_PATH)
        try:
            from apps.core.db import ensure_database

            ensure_database()
        except Exception:  # pragma: no cover - keep the server bootable
            logger.exception("Unable to prepare the legacy database")

    @staticmethod
    def _should_start_workers() -> bool:
        if not getattr(settings, "START_BACKGROUND_JOBS", False):
            return False
        if getattr(settings, "TESTING", False) or getattr(settings, "DISABLE_SCHEDULER", False):
            return False
        argv = sys.argv or []
        command = argv[1] if len(argv) > 1 else ""
        if command in _COMMANDS_WITHOUT_WORKERS:
            return False
        # ``runserver`` imports the apps twice: once in the autoreloader
        # parent and once in the child.  Only the child may start threads.
        # ``--noreload`` has a single process, so it may start them directly.
        if command == "runserver" and getattr(settings, "DEBUG", False):
            if "--noreload" not in argv and os.environ.get("RUN_MAIN") != "true":
                return False
        return True

    def _start_workers(self) -> None:
        # ``ready()`` runs in every WSGI worker; the file lock makes sure only
        # one process owns the scheduler threads (the OS releases it on exit).
        from apps.core.runtime_lock import acquire

        lock = acquire("scheduler")
        if lock is None:
            logger.info("Background workers already running in another process")
            return
        app = None
        try:
            from apps.core.compat import get_app
            from apps.modules.services.messaging_service import MessageJobManager
            from apps.modules.services.scheduler import start_scheduler
            from apps.modules.services.sms_service import SmsJobManager
            from apps.modules.services.update_service import cleanup_on_startup

            app = get_app()
            app.extensions["scheduler_lock"] = lock
            app.extensions.setdefault("sms_jobs", SmsJobManager())
            app.extensions.setdefault("message_jobs", MessageJobManager())
            try:
                cleanup_on_startup(app)
            except Exception:  # pragma: no cover - cleanup is best effort
                logger.debug("Update cleanup failed", exc_info=True)
            start_scheduler(app)
            logger.info("Background workers started")
        except Exception:  # pragma: no cover - never block startup
            logger.exception("Unable to start the background workers")
            if app is not None:
                app.extensions.pop("scheduler_lock", None)
            lock.close()
