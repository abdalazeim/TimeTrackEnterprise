# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller specification for the desktop build.

The entry point is ``desktop/launcher.py``.  Templates, static files and the
JSON locales are shipped inside the bundle; user data stays next to the
executable.
"""
from pathlib import Path

from PyInstaller.utils.hooks import collect_data_files, collect_submodules

ROOT = Path(SPECPATH)
ICON = ROOT / "build_assets" / "TimeTrackEnterprise.ico"
VERSION = ROOT / "build_assets" / "version_info.txt"

datas = [
    (str(ROOT / "templates"), "templates"),
    (str(ROOT / "static"), "static"),
    (str(ROOT / "apps" / "core" / "locales"), "apps/core/locales"),
]
for package in (
    "django",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.messages",
    "django.contrib.sessions",
    "django.contrib.staticfiles",
    "jinja2",
    "barcode",
    "segno",
    "openpyxl",
    "xlrd",
    "bs4",
    "werkzeug",
    "waitress",
):
    datas += collect_data_files(package)

hiddenimports = [
    # Django runtime modules loaded by string reference.
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.messages",
    "django.contrib.sessions",
    "django.contrib.staticfiles",
    "django.db.backends.sqlite3",
    "django.core.management.commands.migrate",
    "django.core.management.commands.collectstatic",
    "django.template.backends.django",
    "django.template.backends.jinja2",
    # Project modules (settings, URLconf, WSGI, template environment).
    "config.settings.base",
    "config.settings.desktop",
    "config.urls",
    "config.api_urls",
    "config.wsgi",
    "config.jinja2",
    "config.desktop_security",
    "apps.accounts.backends",
    "apps.accounts.middleware",
    "apps.core.middleware.compat",
    "apps.core.middleware.language",
    "apps.core.middleware.rate_limit",
    "apps.core.middleware.security",
    "apps.core.context_processors",
    # Optional native dialogs / servers.
    "tkinter",
    "tkinter.messagebox",
    "waitress",
]
hiddenimports += collect_submodules("apps")

a = Analysis(
    [str(ROOT / "desktop" / "launcher.py")],
    pathex=[str(ROOT)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["pytest", "PyInstaller"],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="TimeTrackEnterprise",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ICON),
    version=str(VERSION),
)
