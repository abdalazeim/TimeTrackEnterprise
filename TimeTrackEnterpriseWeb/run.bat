@echo off
setlocal
cd /d "%~dp0"
title TimeTrackEnterprise

rem ---------------------------------------------------------------------------
rem TimeTrack Enterprise - local development / desktop launcher
rem
rem The first run creates a virtual environment, installs the requirements and
rem applies the migrations.  Subsequent runs start the desktop server directly.
rem ---------------------------------------------------------------------------

if not exist ".venv\Scripts\python.exe" (
    echo [1/4] Creating the Python virtual environment...
    py -3 -m venv .venv
    if errorlevel 1 goto :error
)

if not exist ".venv\.installed" (
    echo [2/4] Installing dependencies...
    ".venv\Scripts\python.exe" -m pip install --upgrade pip
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt
    if errorlevel 1 goto :error
    type nul > ".venv\.installed"
)

echo [3/4] Applying database migrations...
".venv\Scripts\python.exe" manage.py migrate --noinput
if errorlevel 1 goto :error

echo [4/4] Starting TimeTrackEnterprise on the network...
".venv\Scripts\python.exe" desktop\launcher.py --host 0.0.0.0 --port 8765 %*
exit /b %errorlevel%

:error
echo.
echo Startup failed. Review the messages above.
pause
exit /b 1
