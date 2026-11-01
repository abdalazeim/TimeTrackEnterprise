from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

APP_NAME = "TimeTrackEnterprise"
APP_VERSION = "1.1.20"
COLOR_THEMES = (
    "emerald",
    "blue",
    "red",
    "orange",
    "yellow",
    "purple",
    "rose",
    "slate",
)
DEFAULT_COLOR_THEME = "emerald"
APP_TITLE = "TimeTrackEnterprise"
APP_SUBTITLE = "الحضور بالباركود وإشعار الأولياء"

UPDATE_FEED_URL = "https://fetsync.org/Update/latest.json"
UPDATE_PUBLIC_KEY = "wfjSP8we/c/RCTDi0DsC7xKYb+pKtzD1RZJLU8DT/sA="
UPDATE_CHECK_INTERVAL = 6 * 60 * 60

GATEWAY_APP_NAME = "Attendance SMS Gateway"
GATEWAY_APP_VERSION = "1.1.0"
GATEWAY_APP_DOWNLOAD_URL = (
    f"https://fetsync.org/Update/Attendance-SMS-Gateway-{GATEWAY_APP_VERSION}.apk"
)
WHATSAPP_DOWNLOAD_URL = "https://www.whatsapp.com/download"

ROLE_LABELS = {
    "admin": "مدير",
    "user": "مستخدم",
}

APP_TRANSLATIONS = {
    "en": {
        "title": "TimeTrackEnterprise",
        "subtitle": "Barcode attendance & parent notifications",
    },
    "fr": {
        "title": "TimeTrackEnterprise",
        "subtitle": "Présence par code-barres et notifications aux parents",
    },
}


def app_metadata(lang: str) -> dict[str, str]:
    meta = APP_TRANSLATIONS.get(lang, {})
    return {
        "app_title": meta.get("title", APP_TITLE),
        "app_subtitle": meta.get("subtitle", APP_SUBTITLE),
    }


PACKAGE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = PACKAGE_DIR.parents[1]


def _frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def bundle_dir() -> Path:
    if _frozen():
        return Path(getattr(sys, "_MEIPASS"))
    return PROJECT_DIR


def template_dir() -> str:
    return str(bundle_dir() / "templates")


def static_dir() -> str:
    return str(bundle_dir() / "static")


def executable_dir() -> Path:
    if _frozen():
        return Path(sys.executable).resolve().parent
    return PROJECT_DIR


def _is_writable(directory: Path) -> bool:
    try:
        directory.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=directory, prefix=".write-test-", delete=True):
            pass
        return True
    except OSError:
        return False


def default_data_dir() -> Path:
    """Portable data folder next to the app, with a safe LocalAppData fallback."""
    override = os.environ.get("ATTENDANCE_DATA_DIR")
    if override:
        path = Path(override).expanduser().resolve()
        path.mkdir(parents=True, exist_ok=True)
        return path

    candidate = executable_dir() / "data"
    if _is_writable(candidate):
        return candidate

    local = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
    fallback = Path(local) / "SmartStudentAttendance" / "data"
    fallback.mkdir(parents=True, exist_ok=True)
    return fallback


def ensure_data_layout(data_dir: Path) -> dict[str, Path]:
    data_dir = Path(data_dir)
    layout = {
        "root": data_dir,
        "photos": data_dir / "photos",
        "uploads": data_dir / "uploads",
        "tmp": data_dir / "tmp",
        "logs": data_dir / "logs",
        "updates": data_dir / "updates",
    }
    for path in layout.values():
        path.mkdir(parents=True, exist_ok=True)
    return layout

