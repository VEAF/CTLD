"""The single-user, in-memory editing session.

Holds the currently-open catalogue plus lazily-loaded default catalogue + schema. One
process = one MM = one session (ADR 0011: no DB, ephemeral).
"""

from __future__ import annotations

from pathlib import Path

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.schema import Schema


class Session:
    def __init__(self) -> None:
        self._catalog: Catalog | None = None
        self._path: Path | None = None
        self._schema: Schema | None = None
        self._default: Catalog | None = None

    # ── loaded catalogue ───────────────────────────────────────────
    @property
    def catalog(self) -> Catalog:
        if self._catalog is None:
            raise LookupError("no catalogue loaded")
        return self._catalog

    @property
    def path(self) -> Path | None:
        return self._path

    def load_path(self, path: str | Path) -> None:
        self._catalog = Catalog.load(path)
        self._path = Path(path)

    def load_text(self, text: str) -> None:
        self._catalog = Catalog.loads(text)
        self._path = None

    def load_default(self) -> None:
        path = resources.default_catalog_path()
        self._catalog = Catalog.load(path)
        self._path = path

    # ── reference data (lazy, cached) ──────────────────────────────
    @property
    def schema(self) -> Schema:
        if self._schema is None:
            self._schema = Schema.load(resources.schema_path())
        return self._schema

    def default_catalog(self) -> Catalog:
        if self._default is None:
            self._default = Catalog.load(resources.default_catalog_path())
        return self._default

    def reset(self) -> None:
        """Drop all state (used between tests)."""
        self._catalog = None
        self._path = None
        self._schema = None
        self._default = None


session = Session()
