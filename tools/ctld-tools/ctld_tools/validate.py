"""Validate a user-config.yaml against the reference catalogue and the DCS type set.

Produces a list of findings (errors block gen-user; warnings do not), each with a
clear message and, where possible, a suggested fix. Mission Makers target crates and
troop groups by name; validation resolves those names and reports the unknowns.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from ruamel.yaml import YAML

from ctld_tools.datamine import known_dcs_types
from ctld_tools.reference import Reference

ERROR = "error"
WARNING = "warning"


@dataclass
class Finding:
    severity: str
    where: str
    message: str

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
            out.append(Finding(ERROR, where, "missing 'name'"))
        unit = entry.get("unit")
        if not unit:
            out.append(Finding(ERROR, where, "missing 'unit'"))
        elif unit not in types:
            out.append(Finding(ERROR, where, f"unknown DCS unit type {unit!r}"))
        weight = entry.get("weight_kg", entry.get("weight"))
        if weight is None:
            out.append(Finding(ERROR, where, "missing 'weight_kg' (crate mass, also its unique key)"))
        elif weight in ref.crate_weights() or weight in seen_new_weights:
            out.append(Finding(ERROR, where, f"weight_kg {weight} collides with an existing crate — must be unique"))
        else:
            seen_new_weights.add(weight)

    for target in crates.get("remove") or []:
        _, err = ref.resolve_crate(target)
        if err:
            out.append(Finding(ERROR, f"crates.remove[{target}]", err))

    for entry in crates.get("patch") or []:
        target = entry.get("name", entry.get("weight"))
        _, err = ref.resolve_crate(target)
        if err:
            out.append(Finding(ERROR, f"crates.patch[{target}]", err))


def _validate_troops(troops: dict, ref: Reference, out: list[Finding]) -> None:
    for entry in troops.get("add") or []:
        if not entry.get("name"):
            out.append(Finding(ERROR, "troops.add", "missing 'name'"))
    for name in troops.get("remove") or []:
        if not ref.troop_exists(name):
            near = ref.closest_troop(name)
            hint = f" — did you mean {near!r}?" if near else ""
            out.append(Finding(ERROR, f"troops.remove[{name}]", f"no troop group named {name!r}{hint}"))


def _validate_arrays(arrays: dict, ref: Reference, out: list[Finding]) -> None:
    for setting in arrays:
        if not ref.is_array_setting(setting):
            out.append(Finding(ERROR, f"arrays.{setting}", f"{setting!r} is not an appendable array setting"))


def validate(user_config: dict, ref: Reference, types=None) -> list[Finding]:
    """Return findings for a parsed user-config against the reference + DCS types."""
    types = known_dcs_types() if types is None else types
    out: list[Finding] = []
    _validate_crates(user_config.get("crates") or {}, ref, types, out)
    _validate_troops(user_config.get("troops") or {}, ref, out)
    _validate_arrays(user_config.get("arrays") or {}, ref, out)
    return out


def has_errors(findings: list[Finding]) -> bool:
    return any(f.severity == ERROR for f in findings)
