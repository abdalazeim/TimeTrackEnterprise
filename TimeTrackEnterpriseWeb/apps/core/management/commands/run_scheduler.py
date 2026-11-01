"""Run the background workers in the foreground.

Use this when the web server must not own the scheduler, for example behind a
multi-worker WSGI server or when a separate service account should run the
absence sweeper, update checker and gateway heartbeat::

    ATTENDANCE_BACKGROUND_JOBS=0 python manage.py run_scheduler

Stop it with ``Ctrl+C`` (or the service manager).  The same cross-process lock
used by ``CoreConfig.ready()`` prevents a second instance from running.
"""
from __future__ import annotations

import time

from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Run the absence sweeper, update checker and gateway heartbeat."

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            "--interval",
            type=int,
            default=60,
            help="Seconds between absence-sweeper ticks (default: 60).",
        )

    def handle(self, *args, **options) -> None:
        from apps.core.compat import get_app
        from apps.core.runtime_lock import acquire
        from apps.modules.services.scheduler import start_scheduler

        lock = acquire("scheduler")
        if lock is None:
            raise CommandError(
                "Another process already owns the scheduler lock "
                "(DATA_DIR/scheduler.lock)."
            )

        app = get_app()
        app.extensions["scheduler_lock"] = lock
        interval = max(5, options["interval"])
        # ``AbsenceScheduler`` reads this when it is constructed below.
        app.config["SCHEDULER_INTERVAL"] = interval
        try:
            scheduler = start_scheduler(app)
            if scheduler is None:
                raise CommandError(
                    "Scheduler is disabled (DISABLE_SCHEDULER or TESTING is set)."
                )
            self.stdout.write(
                self.style.SUCCESS(
                    f"Scheduler running every {interval}s. Press Ctrl+C to stop."
                )
            )
            while True:
                time.sleep(interval)
        except KeyboardInterrupt:
            self.stdout.write("Stopping scheduler...")
        finally:
            for key in ("absence_scheduler", "update_scheduler", "gateway_heartbeat"):
                thread = app.extensions.get(key)
                stop = getattr(thread, "stop", None)
                if callable(stop):
                    stop()
            app.extensions.pop("scheduler_lock", None)
            lock.close()
