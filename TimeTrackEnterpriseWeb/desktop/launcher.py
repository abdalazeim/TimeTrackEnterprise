"""Desktop launcher for TimeTrack Enterprise.

Starts the packaged desktop server.  It:

* applies the desktop settings and the runtime data folder;
* creates/updates the SQLite schema with ``migrate``;
* serves the WSGI application with ``waitress`` on the network interfaces;
* opens the default browser (unless ``--no-browser`` is given);
* shows a native message box if startup fails, because the packaged build has
  no console.

Usage::

    python desktop/launcher.py --host 127.0.0.1 --port 8765
    SmartAttendance.exe --data-dir D:\\school-data --no-browser
"""
from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import webbrowser
from pathlib import Path


def _project_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(getattr(sys, "_MEIPASS"))
    return Path(__file__).resolve().parent.parent


PROJECT_ROOT = _project_root()
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="TimeTrackEnterprise",
        description="TimeTrack Enterprise desktop server",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("ATTENDANCE_HOST", "0.0.0.0"),
        help="Bind address; defaults to all IPv4 interfaces for LAN access.",
    )
    parser.add_argument(
        "--port", type=int, default=int(os.environ.get("ATTENDANCE_PORT", "8765"))
    )
    parser.add_argument("--data-dir", default=os.environ.get("ATTENDANCE_DATA_DIR"))
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--no-scheduler", action="store_true")
    parser.add_argument("--version", action="store_true")
    return parser.parse_args(argv)


def _configure_environment(args: argparse.Namespace) -> tuple[list[dict], list[str]]:
    if args.data_dir:
        os.environ["ATTENDANCE_DATA_DIR"] = str(Path(args.data_dir).expanduser().resolve())
    if args.no_scheduler:
        os.environ["ATTENDANCE_DISABLE_SCHEDULER"] = "1"
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.desktop")

    adapters = _network_adapters()
    ips = _local_ipv4_addresses(adapters)
    if args.host in {"0.0.0.0", "::"} and ips:
        allowed = {
            item.strip()
            for item in os.environ.get("ATTENDANCE_ALLOWED_HOSTS", "").split(",")
            if item.strip()
        }
        allowed.update(ips)
        os.environ["ATTENDANCE_ALLOWED_HOSTS"] = ",".join(sorted(allowed))
    return adapters, ips


def _prepare_django() -> None:
    import django

    django.setup()

    from django.conf import settings
    from django.core.management import call_command

    # The legacy layer creates its own tables from ``CoreConfig.ready``; the
    # ORM tables (sessions, sync, audit) need the normal migration run.
    call_command("migrate", interactive=False, verbosity=0)
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)


def _clean_ipv4(value: object) -> str | None:
    try:
        address = ipaddress.ip_address(str(value).strip())
    except ValueError:
        return None
    if address.version != 4 or address.is_loopback or address.is_link_local:
        return None
    if address.is_unspecified or address.is_multicast:
        return None
    return str(address)


def _windows_network_adapters() -> list[dict] | None:
    """Read every Windows adapter and its IPv4 routes through NetTCPIP."""
    if os.name != "nt":
        return None
    script = r"""
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$rows = @(
    foreach ($adapter in Get-NetAdapter -IncludeHidden) {
        $index = [int]$adapter.ifIndex
        $addresses = @(
            Get-NetIPAddress -InterfaceIndex $index -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.AddressState -ne 'Duplicate' } |
                ForEach-Object { $_.IPAddress } |
                Select-Object -Unique
        )
        $route = Get-NetRoute -InterfaceIndex $index -AddressFamily IPv4 `
            -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric | Select-Object -First 1
        $ipInterface = Get-NetIPInterface -InterfaceIndex $index -AddressFamily IPv4 `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        [PSCustomObject]@{
            name = [string]$adapter.Name
            status = [string]$adapter.Status
            ipv4 = @($addresses)
            default_route = ($null -ne $route)
            route_metric = if ($null -ne $route) { [int]$route.RouteMetric } else { 2147483647 }
            interface_metric = if ($null -ne $ipInterface) { [int]$ipInterface.InterfaceMetric } else { 2147483647 }
        }
    }
)
ConvertTo-Json -InputObject @($rows) -Depth 4 -Compress
"""
    try:
        completed = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=8,
            check=False,
        )
        if completed.returncode != 0 or not completed.stdout.strip():
            return None
        payload = json.loads(completed.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return None

    if isinstance(payload, dict):
        payload = [payload]
    if not isinstance(payload, list):
        return None

    adapters: list[dict] = []
    for item in payload:
        if not isinstance(item, dict):
            continue
        raw_ips = item.get("ipv4") or []
        if isinstance(raw_ips, str):
            raw_ips = [raw_ips]
        ips = list(dict.fromkeys(ip for raw in raw_ips if (ip := _clean_ipv4(raw))))
        try:
            route_metric = int(item.get("route_metric", 2147483647))
        except (TypeError, ValueError):
            route_metric = 2147483647
        try:
            interface_metric = int(item.get("interface_metric", 2147483647))
        except (TypeError, ValueError):
            interface_metric = 2147483647
        adapters.append(
            {
                "name": str(item.get("name") or "Unknown adapter"),
                "status": str(item.get("status") or "Unknown"),
                "ipv4": ips,
                "default_route": bool(item.get("default_route")),
                "route_metric": route_metric,
                "interface_metric": interface_metric,
            }
        )
    return adapters or None


def _ipconfig_network_adapters() -> list[dict]:
    """Fallback for Windows installations without the NetTCPIP cmdlets."""
    try:
        completed = subprocess.run(
            ["ipconfig", "/all"],
            capture_output=True,
            text=True,
            errors="replace",
            timeout=8,
            check=False,
        )
        output = completed.stdout
    except (OSError, subprocess.SubprocessError):
        return []

    adapters: list[dict] = []
    current: dict | None = None
    for line in output.splitlines():
        header = re.match(r"^\s*(?:Ethernet|Wireless LAN|Wi-Fi|Wireless) adapter\s+(.+):\s*$", line, re.I)
        if header:
            if current:
                adapters.append(current)
            current = {
                "name": header.group(1).strip(),
                "status": "Unknown",
                "ipv4": [],
                "default_route": False,
                "route_metric": 2147483647,
                "interface_metric": 2147483647,
            }
            continue
        if current is None:
            continue
        lower = line.lower()
        if "media disconnected" in lower or "media state" in lower and "disconnected" in lower:
            current["status"] = "Disconnected"
        elif "ipv4" in lower and ":" in line:
            candidate = line.split(":", 1)[1].split("(", 1)[0].strip()
            address = _clean_ipv4(candidate)
            if address and address not in current["ipv4"]:
                current["ipv4"].append(address)
        elif "default gateway" in lower:
            current["default_route"] = bool(re.search(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", line))

    if current:
        adapters.append(current)
    for adapter in adapters:
        if adapter["ipv4"] and adapter["status"] == "Unknown":
            adapter["status"] = "Up"
    return adapters


def _network_adapters() -> list[dict]:
    """Return all discovered adapters, not just the first Ethernet/Wi-Fi card."""
    adapters = _windows_network_adapters()
    if adapters:
        return adapters
    adapters = _ipconfig_network_adapters()
    if adapters:
        return adapters

    # Portable best-effort fallback when platform-specific discovery is absent.
    addresses: list[str] = []
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            address = _clean_ipv4(info[4][0])
            if address and address not in addresses:
                addresses.append(address)
    except OSError:
        pass
    if not addresses:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.connect(("8.8.8.8", 80))
                address = _clean_ipv4(sock.getsockname()[0])
                if address:
                    addresses.append(address)
        except OSError:
            pass
    if addresses:
        return [
            {
                "name": socket.gethostname(),
                "status": "Connected",
                "ipv4": addresses,
                "default_route": True,
                "route_metric": 0,
                "interface_metric": 0,
            }
        ]
    return []


def _adapter_is_connected(adapter: dict) -> bool:
    status = str(adapter.get("status") or "").strip().lower()
    disconnected = ("disconnected", "disabled", "not present", "unplugged")
    return bool(adapter.get("ipv4")) and not any(word in status for word in disconnected)


def _preferred_network_adapter(adapters: list[dict]) -> dict | None:
    connected = [adapter for adapter in adapters if _adapter_is_connected(adapter)]
    if not connected:
        return None
    return min(
        connected,
        key=lambda adapter: (
            not bool(adapter.get("default_route")),
            int(adapter.get("route_metric", 2147483647)),
            int(adapter.get("interface_metric", 2147483647)),
            str(adapter.get("name") or "").casefold(),
        ),
    )


def _local_ipv4_addresses(adapters: list[dict] | None = None) -> list[str]:
    adapters = adapters if adapters is not None else _network_adapters()
    connected = [adapter for adapter in adapters if _adapter_is_connected(adapter)]
    if not connected:
        connected = [adapter for adapter in adapters if adapter.get("ipv4")]
    connected.sort(
        key=lambda adapter: (
            not bool(adapter.get("default_route")),
            int(adapter.get("route_metric", 2147483647)),
            int(adapter.get("interface_metric", 2147483647)),
            str(adapter.get("name") or "").casefold(),
        )
    )
    addresses: list[str] = []
    for adapter in connected:
        raw_ips = adapter.get("ipv4") or []
        if isinstance(raw_ips, str):
            raw_ips = [raw_ips]
        for raw in raw_ips:
            address = _clean_ipv4(raw)
            if address and address not in addresses:
                addresses.append(address)
    return addresses


def _free_port(host: str, port: int) -> int:
    """Return ``port`` or the next free port on ``host``."""
    for candidate in range(port, port + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind((host, candidate))
            except OSError:
                continue
            return candidate
    raise OSError(f"No free port found between {port} and {port + 19} on {host}.")


def _open_browser(url: str, delay: float = 1.5) -> None:
    def _open() -> None:
        time.sleep(delay)
        try:
            webbrowser.open_new(url)
        except Exception:  # pragma: no cover - headless session
            pass

    threading.Thread(target=_open, name="open-browser", daemon=True).start()


def _fatal(message: str) -> None:
    """Report a startup error with a native dialog when possible."""
    try:
        import tkinter
        from tkinter import messagebox

        root = tkinter.Tk()
        root.withdraw()
        messagebox.showerror("TimeTrackEnterprise", message)
        root.destroy()
    except Exception:  # pragma: no cover - no tkinter in the environment
        print(message, file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    from apps.core.config import APP_VERSION

    if args.version:
        print(APP_VERSION)
        return 0

    try:
        adapters, ips = _configure_environment(args)
        _prepare_django()

        from waitress import serve

        from config.wsgi import application

        port = _free_port(args.host, args.port)
        if args.host in {"0.0.0.0", "::"}:
            print(
                f"TimeTrack Enterprise {APP_VERSION} listening on all network interfaces (port {port}).",
                flush=True,
            )
        else:
            print(f"TimeTrack Enterprise {APP_VERSION} listening on http://{args.host}:{port}/", flush=True)
        print("Detected network adapters:", flush=True)
        preferred = _preferred_network_adapter(adapters)
        for adapter in adapters:
            adapter_ips = adapter.get("ipv4") or []
            if isinstance(adapter_ips, str):
                adapter_ips = [adapter_ips]
            ip_text = ", ".join(adapter_ips) if adapter_ips else "N/A"
            selected = " [preferred]" if adapter is preferred else ""
            print(
                f"  - {adapter['name']}: status={adapter['status']}, IPv4={ip_text}{selected}",
                flush=True,
            )
        if preferred:
            preferred_ips = preferred.get("ipv4") or []
            if isinstance(preferred_ips, str):
                preferred_ips = [preferred_ips]
            print(
                f"Preferred network adapter: {preferred['name']} ({', '.join(preferred_ips)})",
                flush=True,
            )
        accessible_ips = ips if args.host in {"0.0.0.0", "::"} else [args.host] if args.host in ips else []
        if accessible_ips:
            for ip in accessible_ips:
                print(f"Network access: http://{ip}:{port}/", flush=True)
        else:
            print("No active LAN IPv4 address was detected; local access: http://127.0.0.1:{}/".format(port), flush=True)
        url = "http://127.0.0.1:{}/".format(port)
        if not args.no_browser:
            _open_browser(url)

        serve(
            application,
            host=args.host,
            port=port,
            threads=int(os.environ.get("ATTENDANCE_THREADS", "8")),
            ident="TimeTrackEnterprise",
        )
        return 0
    except KeyboardInterrupt:  # pragma: no cover - interactive shutdown
        return 0
    except Exception as exc:  # pragma: no cover - startup failure path
        _fatal(f"تعذر تشغيل خادم الشبكة:\n{type(exc).__name__}: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
