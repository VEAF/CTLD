"""Authoring-schema accessor — the schema-driven half of the tool core.

`CTLD_config_schema.yaml` carries per-setting authoring metadata (functional `group`,
`standard` flag, `choices` enum, bilingual `description`). It is optional: a setting with
no entry is still editable (the UI falls back to a generic editor). This class gives the
core (and lot-3 UI) typed access to that metadata without re-reading YAML everywhere.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from ruamel.yaml import YAML

# Top-level sections that carry authoring metadata rather than a setting.
_RESERVED = frozenset({"tableFields", "families"})


class Schema:
    """Read-only view over CTLD_config_schema.yaml."""

    def __init__(self, entries: dict[str, Any]) -> None:
        self._e = entries

    @classmethod
    def load(cls, path: str | Path) -> Schema:
        y = YAML(typ="safe")
        data = y.load(Path(path).read_text(encoding="utf-8")) or {}
        return cls(data)

    def has(self, key: str) -> bool:
        return key in self._e

    def _entry(self, key: str) -> dict[str, Any]:
        e = self._e.get(key)
        return e if isinstance(e, dict) else {}

    def group(self, key: str) -> str | None:
        """The functional family key, or None (uncovered → generic editor)."""
        return self._entry(key).get("group")

    def standard(self, key: str) -> bool:
        """True = surfaced in the Standard view; False/absent = Advanced."""
        return bool(self._entry(key).get("standard", False))

    def choices(self, key: str) -> list[Any] | None:
        return self._entry(key).get("choices")

    def default(self, key: str) -> Any:
        return self._entry(key).get("default")

    def description(self, key: str, lang: str = "en") -> str | None:
        desc = self._entry(key).get("description")
        return desc.get(lang) if isinstance(desc, dict) else None

    def families(self) -> list[str]:
        """The distinct functional families declared across the schema, sorted."""
        return sorted({g for k in self.keys() if (g := self.group(k))})

    def table_fields(self) -> dict[str, Any]:
        """Per-field authoring metadata for structured tables (crates, troops, zones, …)."""
        tf = self._e.get("tableFields")
        return tf if isinstance(tf, dict) else {}

    def keys(self) -> list[str]:
        """Every setting key (excluding the reserved metadata sections)."""
        return [k for k in self._e if k not in _RESERVED]

    # ── families ───────────────────────────────────────────────────
    def family_meta(self) -> dict[str, Any]:
        """The reserved `families:` section — per-family label / description / order."""
        fam = self._e.get("families")
        return fam if isinstance(fam, dict) else {}

    def _family_entry(self, family: str) -> dict[str, Any]:
        entry = self.family_meta().get(family)
        return entry if isinstance(entry, dict) else {}

    def family_label(self, family: str, lang: str = "en") -> str | None:
        label = self._family_entry(family).get("label")
        return label.get(lang) or label.get("en") if isinstance(label, dict) else None

    def family_description(self, family: str, lang: str = "en") -> str | None:
        desc = self._family_entry(family).get("description")
        return desc.get(lang) or desc.get("en") if isinstance(desc, dict) else None

    def family_order(self, family: str) -> int:
        """Navigation rank; families without one sort last (but before `other`'s explicit 999)."""
        order = self._family_entry(family).get("order")
        return int(order) if isinstance(order, int) else 998
