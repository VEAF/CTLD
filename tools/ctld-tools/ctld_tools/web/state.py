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
        # Set when the open configuration came out of a mission, so an install can go back to it.
        self._mission_path: Path | None = None
        # "file" (this tool's install, or a .yaml) or "inline" (a mission installed by rc1–rc3).
        self._config_shape: str = "file"

    # ── loaded catalogue ───────────────────────────────────────────
    @property
    def catalog(self) -> Catalog:
        if self._catalog is None:
            raise LookupError("no catalogue loaded")
        return self._catalog

    @property
    def path(self) -> Path | None:
        return self._path

    @property
    def mission_path(self) -> Path | None:
        """The `.miz` the open configuration was read from, if any."""
        return self._mission_path

    @property
    def config_shape(self) -> str:
        """How the open configuration was stored: `"file"` or `"inline"`."""
        return self._config_shape

    def load_path(self, path: str | Path) -> None:
        """Open a configuration — a `.yaml`, or the one inside a `.miz`.

        A mission is where a Mission Maker's configuration actually lives once installed, so opening
        one has to work: otherwise last month's mission can only be reconfigured from scratch. Both
        storage shapes are read (see `install.read_config`), and `mission_path` remembers which
        mission it came from so the next install defaults to it.
        """
        path = Path(path)
        if path.suffix.lower() == ".miz":
            from ctld_tools.install import read_config

            found = read_config(path)
            if found is None:
                raise ValueError(f"no CTLD configuration in {path.name}")
            self._catalog = Catalog.loads(found.yaml)
            self._path = None
            self._mission_path = path
            self._config_shape = found.shape
            return
        self._catalog = Catalog.load(path)
        self._path = path
        self._mission_path = None
        self._config_shape = "file"

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
