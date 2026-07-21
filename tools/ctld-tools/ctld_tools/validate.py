"""Validate a user-config.yaml against the reference catalogue and the DCS type set.

Produces a list of findings (errors block gen-user; warnings do not), each with a
clear message and, where possible, a suggested fix. Mission Makers target crates and
troop groups by name; validation resolves those names and reports the unknowns.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from ruamel.yaml import YAML

from ctld_tools.datamine import known_dcs_types
from ctld_tools.i18n import t
from ctld_tools.reference import Reference

ERROR = "error"
WARNING = "warning"


@dataclass
class Finding:
    """A validation finding as an i18n key + params; `.message` is translated on access."""

    severity: str
    where: str
    key: str
    params: dict = field(default_factory=dict)

    @property
    def message(self) -> str:
        return t(self.key, **self.params)

    def __str__(self) -> str:
        return f"[{self.severity}] {self.where}: {self.message}"


def load_user_config(path: str | Path) -> dict:
    yaml = YAML(typ="safe")
    with Path(path).open("r", encoding="utf-8") as fh:
        doc = yaml.load(fh)
    return doc or {}


def _validate_crates(crates: dict, ref: Reference, types, out: list[Finding]) -> None:
    seen_new_weights: set[float] = set()
    for entry in crates.get("add") or []:
        where = f"crates.add[{entry.get('name', '?')}]"
        if not entry.get("name"):
            out.append(Finding(ERROR, where, "validate.crate.missing_name"))
        unit = entry.get("unit")
        if not unit:
            out.append(Finding(ERROR, where, "validate.crate.missing_unit"))
        elif unit not in types:
            out.append(Finding(ERROR, where, "validate.crate.unknown_unit", {"unit": unit}))
        weight = entry.get("weight_kg", entry.get("weight"))
        if weight is None:
            out.append(Finding(ERROR, where, "validate.crate.missing_weight"))
        elif weight in ref.crate_weights() or weight in seen_new_weights:
            out.append(Finding(ERROR, where, "validate.crate.weight_collision", {"weight": weight}))
        else:
            seen_new_weights.add(weight)

    for target in crates.get("remove") or []:
        _, err = ref.resolve_crate(target)
        if err:
            out.append(Finding(ERROR, f"crates.remove[{target}]", err.key, err.params))

    for entry in crates.get("patch") or []:
        target = entry.get("name", entry.get("weight"))
        current, err = ref.resolve_crate(target)
        where = f"crates.patch[{target}]"
        if err:
            out.append(Finding(ERROR, where, err.key, err.params))
            continue
        # A patch may change the weight (the crate key); the new one must stay unique
        # (compared against every other crate — the target's own current weight excepted).
        new_weight = entry.get("weight_kg")
        if new_weight is not None and new_weight != current:
            others = (ref.crate_weights() - {current}) | seen_new_weights
            if new_weight in others:
                out.append(Finding(ERROR, where, "validate.crate.weight_collision", {"weight": new_weight}))


def _troop_unknown(name, ref: Reference) -> Finding:
    near = ref.closest_troop(name)
    if near:
        return Finding(ERROR, f"troops[{name}]", "validate.troop.unknown_hint", {"name": name, "suggestion": near})
    return Finding(ERROR, f"troops[{name}]", "validate.troop.unknown", {"name": name})


def _validate_troops(troops: dict, ref: Reference, out: list[Finding]) -> None:
    for entry in troops.get("add") or []:
        if not entry.get("name"):
            out.append(Finding(ERROR, "troops.add", "validate.troop.missing_name"))
    for name in troops.get("remove") or []:
        if not ref.troop_exists(name):
            out.append(_troop_unknown(name, ref))
    for entry in troops.get("patch") or []:
        name = entry.get("name")
        if not name:
            out.append(Finding(ERROR, "troops.patch", "validate.troop.missing_name"))
        elif not ref.troop_exists(name):
            out.append(_troop_unknown(name, ref))


def _validate_arrays(arrays: dict, ref: Reference, out: list[Finding]) -> None:
    for setting in arrays:
        if not ref.is_array_setting(setting):
            out.append(Finding(ERROR, f"arrays.{setting}", "validate.array.not_appendable", {"setting": setting}))


def _validate_settings(settings: dict, ref: Reference, out: list[Finding]) -> None:
    # An unknown scalar setting is a warning, not an error: it is silently ignored in
    # game (a likely typo) but does not break generation, and the catalogue may not be
    # exhaustive (e.g. plugin settings).
    for name in settings:
        if not ref.setting_exists(name):
            near = ref.closest_setting(name)
            if near:
                out.append(
                    Finding(
                        WARNING, f"settings.{name}", "validate.setting.unknown_hint", {"name": name, "suggestion": near}
                    )
                )
            else:
                out.append(Finding(WARNING, f"settings.{name}", "validate.setting.unknown", {"name": name}))


def validate(user_config: dict, ref: Reference, types=None) -> list[Finding]:
    """Return findings for a parsed user-config against the reference + DCS types."""
    types = known_dcs_types() if types is None else types
    out: list[Finding] = []
    _validate_crates(user_config.get("crates") or {}, ref, types, out)
    _validate_troops(user_config.get("troops") or {}, ref, out)
    _validate_arrays(user_config.get("arrays") or {}, ref, out)
    _validate_settings(user_config.get("settings") or {}, ref, out)
    return out


def has_errors(findings: list[Finding]) -> bool:
    return any(f.severity == ERROR for f in findings)
