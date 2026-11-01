"""Page routes for the functional modules."""
from __future__ import annotations

from apps.core.compat import urlpatterns_for
from apps.modules.views import views_bp

urlpatterns = urlpatterns_for(views_bp)
