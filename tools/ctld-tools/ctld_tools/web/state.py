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
        # The bytes of each customised beacon sound, keyed by setting name. Filled either from the
        # disk (the MM just picked a file) or from the archive (they just opened a mission that
        # carries one) — one notion, two sources. Keeping a *path* instead would rot: the file
        # moves, the drive is unplugged, the configuration is reopened on another machine; and a
        # mission has no path to offer at all.
        self._sounds: dict[str, bytes] = {}

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

        A mission also carries its **sounds**, so a customised one is recovered here — that is what
        makes an installed mission reconfigurable months later, on another machine, with the
        original file long gone. A `.yaml` cannot carry one (a binary has no place in the
        configuration document), so opening one leaves the sounds empty and validation asks for the
        file before the next install.
        """
        path = Path(path)
        self._sounds = {}
        if path.suffix.lower() == ".miz":
            from ctld_tools.install import read_config, read_sounds_from_miz

            found = read_config(path)
            if found is None:
                raise ValueError(f"no CTLD configuration in {path.name}")
            self._catalog = Catalog.loads(found.yaml)
            self._path = None
            self._mission_path = path
            self._config_shape = found.shape
            self._sounds = read_sounds_from_miz(path, self._catalog)
            return
        self._catalog = Catalog.load(path)
        self._path = path
        self._mission_path = None
        self._config_shape = "file"

    def load_text(self, text: str) -> None:
        self._catalog = Catalog.loads(text)
        self._path = None
        self._sounds = {}

    def load_default(self) -> None:
        path = resources.default_catalog_path()
        self._catalog = Catalog.load(path)
        self._path = path
        self._sounds = {}

    # ── custom beacon sounds ───────────────────────────────────────
    def set_sound(self, setting: str, data: bytes) -> None:
        """Hold the bytes of a customised sound for `setting`."""
        self._sounds[setting] = data

    def sound(self, setting: str) -> bytes | None:
        """The bytes held for `setting`, or None when it uses the bundled sound."""
        return self._sounds.get(setting)

    def drop_sound(self, setting: str) -> None:
        self._sounds.pop(setting, None)

    def sounds(self) -> dict[str, bytes]:
        """Every customised sound currently held, keyed by setting name."""
        return dict(self._sounds)

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
        self._mission_path = None
        self._config_shape = "file"
        self._sounds = {}


session = Session()
