"""The CTLD default catalogue, used to resolve and validate user-config targets.

Loaded from src/CTLD_config.lua (via lupa) with AA crates injected, so crate names
— including AA-system crates — resolve to their unique weight. Mission Makers refer
to crates and troop groups by name; this maps names to the weight/keys the runtime
helpers expect.
"""

from __future__ import annotations

import difflib
from pathlib import Path

from ctld_tools.luaconfig import load_default_settings

ARRAY_SETTINGS = ("transportPilotNames", "troopZones", "wpZones", "extractableGroups", "logisticUnits")


def _closest(name: str, pool) -> str | None:
    matches = difflib.get_close_matches(name, list(pool), n=1, cutoff=0.7)
    return matches[0] if matches else None


class Reference:
    """Index of the default catalogue: crate names→weights, troop names, arrays."""

    def __init__(self, settings: dict):
        self.settings = settings
        self._crate_by_name: dict[str, list[tuple[float, str]]] = {}
        self._weights: set[float] = set()
        for section, entries in (settings.get("spawnableCrates") or {}).items():
            for entry in entries:
                weight = entry.get("weight")
                if weight is None:
                    continue
                self._weights.add(weight)
                desc = entry.get("desc")
                if desc:
                    self._crate_by_name.setdefault(desc, []).append((weight, section))
        self._troop_names = {g.get("name") for g in (settings.get("loadableGroups") or []) if g.get("name")}

    @classmethod
    def from_src(cls, src_dir: str | Path) -> Reference:
        return cls(load_default_settings(src_dir, inject_aa=True))

    def crate_weights(self) -> set[float]:
        return set(self._weights)

    def resolve_crate(self, target) -> tuple[float | None, str | None]:
        """Resolve a crate target (a name, or a raw weight) to (weight, error).

        Returns (weight, None) on success, or (None, message) with a clear reason.
        """
        if isinstance(target, (int, float)) and not isinstance(target, bool):
            if target in self._weights:
                return float(target), None
            return None, f"no crate with weight {target}"
        matches = self._crate_by_name.get(target, [])
        if not matches:
            near = _closest(str(target), self._crate_by_name.keys())
            hint = f" — did you mean {near!r}?" if near else ""
            return None, f"no crate named {target!r}{hint}"
        if len(matches) > 1:
            weights = ", ".join(str(w) for w, _ in matches)
            return None, f"crate name {target!r} is ambiguous ({weights}); target it by weight instead"
        return matches[0][0], None

    def troop_exists(self, name) -> bool:
        return name in self._troop_names

    def closest_troop(self, name) -> str | None:
        return _closest(str(name), self._troop_names)

    def is_array_setting(self, name) -> bool:
        return name in ARRAY_SETTINGS
