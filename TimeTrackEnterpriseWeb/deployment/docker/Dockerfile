# syntax=docker/dockerfile:1
#
# TimeTrack Enterprise - production container.
#
# Build from the repository root:
#   docker build -f deployment/docker/Dockerfile -t timetrack-enterprise .
#
# The SQLite database and the uploaded files live in /app/data, which must be
# a volume.  Static files are collected into /app/staticfiles and served by
# Nginx (see deployment/nginx/timetrack.conf), never by the WSGI server.

FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DJANGO_SETTINGS_MODULE=config.settings.production \
    ATTENDANCE_DATA_DIR=/app/data \
    ATTENDANCE_SSL_REDIRECT=0

WORKDIR /app

# tzdata keeps Africa/Algiers available; curl is not needed because the
# healthcheck uses the standard library.
RUN apt-get update \
    && apt-get install -y --no-install-recommends tzdata \
    && rm -rf /var/lib/apt/lists/*

# Dependencies first so source changes do not invalidate the pip layer.
COPY requirements.txt ./
RUN python -m pip install --upgrade pip \
    && python -m pip install -r requirements.txt

COPY . .

# Runtime folders are created before dropping privileges so the unprivileged
# user owns the SQLite directory and can create its WAL files.
RUN mkdir -p /app/data /app/staticfiles \
    && python manage.py collectstatic --noinput \
    && addgroup --system app \
    && adduser --system --ingroup app --home /app app \
    && chown -R app:app /app/data /app/staticfiles

USER app

EXPOSE 8000

VOLUME ["/app/data"]

# ``migrate`` is idempotent and creates both the Django tables and the
# hand-written legacy schema (apps/core/migrations/0001_legacy_schema.py).
CMD ["sh", "-c", "python manage.py migrate --noinput && python manage.py collectstatic --noinput && exec gunicorn config.wsgi:application --config deployment/gunicorn/gunicorn.conf.py"]
