"""Authentication URL patterns (``/login``, ``/logout``)."""
from __future__ import annotations

from apps.accounts.views import auth_bp
from apps.core.compat import urlpatterns_for

urlpatterns = urlpatterns_for(auth_bp)
