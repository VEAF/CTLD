"""The ctld-tools local web app — a thin FastAPI presentation layer over the core library.

Single user, ephemeral: no DB, no auth, no migrations (ADR 0011 point 7). Every endpoint is
a thin wrapper over `ctld_tools` core (catalog / schema / validate / versiongap / embed / miz);
no business logic lives here.
"""

from __future__ import annotations
