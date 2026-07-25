"""The CTLD default catalogue, used to resolve and validate user-config targets.

Loaded from src/CTLD_config.lua (via lupa) with AA crates injected, so crate names
— including AA-system crates — resolve to their unique weight. Mission Makers refer
to crates and troop groups by name; this maps names to the weight/keys the runtime
helpers expect.
"""

from __future__ import annotations

import difflib
import json
from dataclasses import dataclass, field
from pathlib import Path

ARRAY_SETTINGS = ("transportPilotNames", "troopZones", "wpZones", "extractableGroups", "logisticUnits")


@dataclass
class RefError:
    """A resolution failure as an i18n key + format params (translated when displayed)."""

    key: str
    params: dict = field(default_factory=dict)


def _closest(name: str, pool) -> str | None:
    matches = difflib.get_close_matches(name, list(pool), n=1, cutoff=0.7)
    return matches[0] if matches else None


def load_setting_schema(src_dir: str | Path) -> dict:
    """Read src/CTLD_config_schema.yaml (authoring metadata: choices, …); {} if absent."""
    from ruamel.yaml import YAML

    path = Path(src_dir) / "CTLD_config_schema.yaml"
    if not path.exists():
        return {}
    yaml = YAML(typ="safe")
    with path.open("r", encoding="utf-8") as fh:
        return yaml.load(fh) or {}


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
        # Full default entries by name, for pre-filling the modify form (first wins on dup).
        self._troop_by_name: dict[str, dict] = {}
        for group in settings.get("loadableGroups") or []:
            name = group.get("name")
            if name and name not in self._troop_by_name:
                self._troop_by_name[name] = dict(group)
        self._crate_entry_by_name: dict[str, dict] = {}
        for section, entries in (settings.get("spawnableCrates") or {}).items():
            for entry in entries:
                desc = entry.get("desc")
                if desc and desc not in self._crate_entry_by_name:
                    self._crate_entry_by_name[desc] = {"section": section, **entry}
        explicit = settings.get("scalarSettings")
        if explicit is not None:
            self._scalar_settings: dict = dict(explicit)
        else:
            self._scalar_settings = {k: v for k, v in settings.items() if isinstance(v, (bool, int, float, str))}
        self._setting_schema: dict = settings.get("settingSchema") or {}
        # Schema settings carrying a `default` live outside the engine catalogue (e.g.
        # i18n_lang, a bare ctld global) — surface them so the picker/validation know them.
        for name, entry in self._setting_schema.items():
            if isinstance(entry, dict) and "default" in entry and name not in self._scalar_settings:
                self._scalar_settings[name] = entry["default"]

    @classmethod
    def from_src(cls, src_dir: str | Path) -> Reference:
        """Resolve the catalogue live from src/ (lupa). Dev override; needs the repo."""
        from ctld_tools.luaconfig import load_default_settings

        settings = load_default_settings(src_dir)
        settings["settingSchema"] = load_setting_schema(src_dir)
        return cls(settings)

    @classmethod
    def from_embedded(cls) -> Reference:
        """Resolve the catalogue from the committed bundle. Default; no src/, no lupa."""
        from ctld_tools.genreference import BUNDLE_PATH

        return cls(json.loads(BUNDLE_PATH.read_text(encoding="utf-8")))

    def crate_weights(self) -> set[float]:
        return set(self._weights)

    def crate_names(self) -> list[str]:
        """Catalogue crate names, sorted — for the remove/patch pickers."""
        return sorted(self._crate_by_name)

    def troop_names(self) -> list[str]:
        """Catalogue troop-group names, sorted — for the remove troop picker."""
        return sorted(name for name in self._troop_names if name)

    def troop_default(self, name) -> dict:
        """The full default troop-group entry for `name` (form-shaped), or {}."""
        return dict(self._troop_by_name.get(name, {}))

    def crate_default(self, name) -> dict:
        """The full default crate entry for `name`, mapped to Add-form keys, or {}.

        `desc`→`name`, `weight`→`weight_kg`; drops keys with no value.
        """
        entry = self._crate_entry_by_name.get(name)
        if not entry:
            return {}
        mapped = {
            "section": entry.get("section"),
            "name": entry.get("desc"),
            "unit": entry.get("unit"),
            "weight_kg": entry.get("weight"),
            "side": entry.get("side"),
            "cratesRequired": entry.get("cratesRequired"),
        }
        return {k: v for k, v in mapped.items() if v is not None}

    def scalar_settings(self) -> dict:
        """Scalar setting names → default value — for the Set setting picker/help."""
        return dict(self._scalar_settings)

    def setting_exists(self, name) -> bool:
        return name in self._scalar_settings

    def enum_choices(self, name) -> list[str] | None:
        """Allowed values for an enum setting (from the schema), or None if free-form."""
        choices = (self._setting_schema.get(name) or {}).get("choices")
        return list(choices) if choices else None

    def setting_description(self, name, lang: str = "en") -> str | None:
        """Help text for a setting in `lang` (falls back to EN), or None if undocumented."""
        desc = (self._setting_schema.get(name) or {}).get("description")
        if not isinstance(desc, dict):
            return None
        return desc.get(lang) or desc.get("en")

    def closest_setting(self, name) -> str | None:
        return _closest(str(name), self._scalar_settings.keys())

    def resolve_crate(self, target) -> tuple[float | None, RefError | None]:
        """Resolve a crate target (a name, or a raw weight) to (weight, error).

        Returns (weight, None) on success, or (None, RefError) with an i18n key + params.
        """
        if isinstance(target, (int, float)) and not isinstance(target, bool):
            if target in self._weights:
                return float(target), None
            return None, RefError("validate.crate.no_weight", {"weight": target})
        matches = self._crate_by_name.get(target, [])
        if not matches:
            near = _closest(str(target), self._crate_by_name.keys())
            if near:
                return None, RefError("validate.crate.unknown_hint", {"name": target, "suggestion": near})
            return None, RefError("validate.crate.unknown", {"name": target})
        if len(matches) > 1:
            weights = ", ".join(str(w) for w, _ in matches)
            return None, RefError("validate.crate.ambiguous", {"name": target, "weights": weights})
        return matches[0][0], None

    def troop_exists(self, name) -> bool:
        return name in self._troop_names

    def closest_troop(self, name) -> str | None:
        return _closest(str(name), self._troop_names)

    def is_array_setting(self, name) -> bool:
        return name in ARRAY_SETTINGS
