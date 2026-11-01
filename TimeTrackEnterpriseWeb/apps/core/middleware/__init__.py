"""Core middleware package.

``CompatRequestMiddleware`` is the bridge between Django and the migrated
Flask-style modules; the other middleware classes are small optional
building blocks used by the deployment variants.
"""
from __future__ import annotations

from apps.core.middleware.compat import CompatRequestMiddleware
from apps.core.middleware.language import LanguageSwitchMiddleware
from apps.core.middleware.rate_limit import RateLimitMiddleware
from apps.core.middleware.security import SecurityHeadersMiddleware

__all__ = [
    "CompatRequestMiddleware",
    "LanguageSwitchMiddleware",
    "RateLimitMiddleware",
    "SecurityHeadersMiddleware",
]
