"""Gunicorn configuration for TimeTrack Enterprise.

Start it with the WSGI entry point::

    gunicorn config.wsgi:application --config deployment/gunicorn/gunicorn.conf.py

Every value can be overridden with an environment variable so the same file
works for Docker, systemd and a manual deployment.

Notes
-----
* ``gthread`` workers are used because the application is I/O bound and the
  scanner bridge keeps short long-poll requests open.
* The SQLite database is shared by all workers. WAL mode is enabled by
  ``apps/core/db.py``; keep the worker count small (the school server is
  modest) and never point two *containers* at the same database file over a
  network share.
* ``preload_app`` stays disabled so each worker opens its own SQLite
  connection; ``apps/core/runtime_lock.py`` then guarantees that only one
  worker starts the scheduler threads.
"""
from __future__ import annotations

import multiprocessing
import os


def _int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except (TypeError, ValueError):
        return default


bind = os.environ.get("GUNICORN_BIND", "0.0.0.0:8000")
backlog = _int("GUNICORN_BACKLOG", 2048)

# 2 x CPUs + 1 is the usual starting point; cap it because SQLite writes
# serialise and the embedded scheduler must not run in several workers.
workers = _int("GUNICORN_WORKERS", min(multiprocessing.cpu_count() * 2 + 1, 4))
worker_class = "gthread"
threads = _int("GUNICORN_THREADS", 4)
worker_connections = _int("GUNICORN_CONNECTIONS", 200)

timeout = _int("GUNICORN_TIMEOUT", 120)
graceful_timeout = _int("GUNICORN_GRACEFUL_TIMEOUT", 30)
keepalive = _int("GUNICORN_KEEPALIVE", 5)
max_requests = _int("GUNICORN_MAX_REQUESTS", 2000)
max_requests_jitter = _int("GUNICORN_MAX_REQUESTS_JITTER", 200)

# Log to stdout/stderr so Docker and systemd collect everything.
accesslog = os.environ.get("GUNICORN_ACCESS_LOG", "-")
errorlog = os.environ.get("GUNICORN_ERROR_LOG", "-")
loglevel = os.environ.get("GUNICORN_LOG_LEVEL", "info")
access_log_format = '%(h)s %(t)s "%(r)s" %(s)s %(b)s %(L)ss "%(a)s"'

# Trust the Nginx proxy for the client address.
forwarded_allow_ips = os.environ.get("GUNICORN_FORWARDED_ALLOW_IPS", "*")
proxy_allow_ips = forwarded_allow_ips

# Restart workers periodically.  A restarted worker re-runs ``ready()`` and
# takes the scheduler lock only if the previous owner has exited.
preload_app = False

proc_name = "timetrack"
