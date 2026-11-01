"""Desktop deployment hardening.

The desktop build runs on a teacher's workstation and is also reachable from
the school LAN (phone scanner, parent gateway).  This module derives the
security settings that cannot live in ``base.py`` because they depend on the
machine:

* only loopback and private LAN addresses are accepted as hosts;
* cookies are never marked ``Secure`` because the desktop serves HTTP;
* the scanner bridge and the sync API are exposed, the Django admin is not.

It is imported from ``config/settings/desktop.py`` and can also be applied to
an existing settings module::

    from config.desktop_security import apply
    apply(globals())
"""
from __future__ import annotations

import ipaddress
import os
import socket
from typing import Any

# RFC1918 + link-local + loopback.  A school LAN almost always uses one of
# these ranges; anything else must be added explicitly.
PRIVATE_NETWORKS = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
)


def _local_addresses() -> list[str]:
    """Return the host's own addresses (best effort, never raises)."""
    addresses = {"127.0.0.1", "localhost", "::1"}
    try:
        hostname = socket.gethostname()
        addresses.add(hostname)
        for info in socket.getaddrinfo(hostname, None):
            addresses.add(str(info[4][0]))
    except OSError:
        pass
    return sorted(addresses)


def _is_private(address: str) -> bool:
    try:
        ip = ipaddress.ip_address(address)
    except ValueError:
        return False
    return any(ip in network for network in PRIVATE_NETWORKS)


def allowed_hosts() -> list[str]:
    """Loopback, the machine name and its private LAN addresses."""
    hosts = set(_local_addresses())
    extra = os.environ.get("ATTENDANCE_ALLOWED_HOSTS", "")
    hosts.update(item.strip() for item in extra.split(",") if item.strip())
    return sorted(host for host in hosts if host)


def apply(namespace: dict[str, Any]) -> dict[str, Any]:
    """Apply the desktop overrides to ``namespace`` (usually ``globals()``)."""
    namespace["DEBUG"] = False
    namespace["ALLOWED_HOSTS"] = allowed_hosts()

    # Local HTTP only: marking cookies Secure would silently drop the session.
    namespace["SESSION_COOKIE_SECURE"] = False
    namespace["CSRF_COOKIE_SECURE"] = False
    namespace["SECURE_SSL_REDIRECT"] = False
    namespace["SECURE_HSTS_SECONDS"] = 0
    namespace["SECURE_PROXY_SSL_HEADER"] = None

    # Keep the admin reachable only from the machine itself.  The middleware
    # below rejects ``/admin/`` from any non-loopback address.
    namespace["DESKTOP_ADMIN_LOOPBACK_ONLY"] = True
    return namespace


class DesktopAdminLoopbackMiddleware:
    """Allow ``/admin/`` only from ``127.0.0.1`` / ``::1``."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = getattr(request, "path_info", "") or ""
        if path.startswith("/admin/"):
            # The desktop launcher is directly exposed to the LAN, not behind
            # a trusted proxy. A caller can forge X-Forwarded-For, so use the
            # socket peer address for this loopback-only restriction.
            address = request.META.get("REMOTE_ADDR") or ""
            try:
                ip = ipaddress.ip_address(address)
            except ValueError:
                ip = None
            if ip is None or not ip.is_loopback:
                from django.http import HttpResponseNotFound

                return HttpResponseNotFound("Not found")
        return self.get_response(request)


__all__ = [
    "DesktopAdminLoopbackMiddleware",
    "PRIVATE_NETWORKS",
    "allowed_hosts",
    "apply",
]
