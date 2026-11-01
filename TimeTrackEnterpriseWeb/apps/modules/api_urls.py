"""JSON API for the functional modules (``/api``)."""
from __future__ import annotations

from apps.core.compat import urlpatterns_for
from apps.modules.api import api_bp

urlpatterns = urlpatterns_for(api_bp)
