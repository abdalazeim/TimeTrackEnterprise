"""Security service: rate limiting and IP checks."""
from __future__ import annotations

from django.conf import settings


def is_local_address(ip_address: str | None) -> bool:
    if not ip_address:
        return False
    local = {"127.0.0.1", "::1", "localhost"}
    return ip_address in local or ip_address.startswith(("10.", "192.168.", "172."))


def require_local(ip_address: str | None) -> None:
    if not is_local_address(ip_address):
        from django.core.exceptions import PermissionDenied

        raise PermissionDenied("This operation is available from the server machine only.")