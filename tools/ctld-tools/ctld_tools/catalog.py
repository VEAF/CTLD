"""The complete-catalogue model — UI-agnostic core for editing a CTLD config YAML.

A `Catalog` wraps a round-trip ruamel document (comments + order preserved) and exposes
the config as one flat namespace of settings, over the readability sections
(`mm_facing` / `advanced`) plus top-level keys (`configVersion`). It edits the *complete*
catalogue — settings and data (crates, troops, zones, capabilities) — not a diff.

Schema metadata (`CTLD_config_schema.yaml`: group / standard / choices / description)
is optional and only *describes* settings; a setting with no schema entry is still fully
addressable here (the UI falls back to a generic editor).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from ruamel.yaml import YAML

_SECTIONS = ("mm_facing", "advanced")


def _yaml() -> YAML:
    y = YAML()  # round-trip mode by default: preserves comments, order, styles
    y.preserve_quotes = True
    y.width = 4096  # never wrap long scalars
    return y


class Catalog:
    """A complete CTLD config catalogue, loaded from YAML and editable in full."""

    def __init__(self, doc: Any) -> None:
        self._doc = doc

    # ── load / save ────────────────────────────────────────────────
    @classmethod
    def load(cls, path: str | Path) -> Catalog:
        text = Path(path).read_text(encoding="utf-8")
        return cls(_yaml().load(text))

    @classmethod
    def loads(cls, text: str) -> Catalog:
        return cls(_yaml().load(text))

    def save(self, path: str | Path) -> None:
        with Path(path).open("w", encoding="utf-8", newline="\n") as fh:
            _yaml().dump(self._doc, fh)

    def dumps(self) -> str:
        import io

        buf = io.StringIO()
        _yaml().dump(self._doc, buf)
        return buf.getvalue()

    # ── settings (scalars living in a section or at top level) ─────
    def _find_section(self, key: str) -> Any:
        """Return the container holding `key` (a section map or the root), or None."""
        for name in _SECTIONS:
            sec = self._doc.get(name)
            if sec is not None and key in sec:
                return sec
        if key in self._doc and key not in _SECTIONS:
            return self._doc
        return None

    def keys(self) -> list[str]:
        """Every setting/data key, across the sections and top level."""
        out: list[str] = []
        for name in _SECTIONS:
            sec = self._doc.get(name)
            if sec is not None:
                out.extend(sec.keys())
        out.extend(k for k in self._doc if k not in _SECTIONS)
        return out

    def has(self, key: str) -> bool:
        return self._find_section(key) is not None

    def get(self, key: str, default: Any = None) -> Any:
        container = self._find_section(key)
        return default if container is None else container[key]

    def set(self, key: str, value: Any) -> None:
        """Update an existing setting in place (in the section where it already lives)."""
        container = self._find_section(key)
        if container is None:
            raise KeyError(f"unknown setting: {key!r} (use add_setting to create it)")
        container[key] = value

    def add_setting(self, key: str, value: Any, *, section: str = "advanced") -> None:
        """Create a new setting in a given section (default: advanced)."""
        if self.has(key):
            raise KeyError(f"setting already exists: {key!r}")
        if section not in _SECTIONS:
            raise ValueError(f"section must be one of {_SECTIONS}, got {section!r}")
        target = self._doc.setdefault(section, {})
        target[key] = value

    def remove(self, key: str) -> None:
        """Remove a setting/data key wherever it lives (missing = absent at runtime)."""
        container = self._find_section(key)
        if container is None:
            raise KeyError(f"unknown key: {key!r}")
        del container[key]

    # ── data structures (spawnableCrates, loadableGroups, zones, …) ─
    def data(self, key: str) -> Any:
        """The live list/map stored under `key` (mutate it directly to edit)."""
        return self.get(key)
