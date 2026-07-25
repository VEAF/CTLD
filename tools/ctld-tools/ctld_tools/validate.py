"""Validate a complete config catalogue (the ADR-0011 model, not a diff).

Checks the whole `Catalog`:
  - every crate `unit` is a known DCS type (datamine),
  - crate `weight`s are globally unique (the weight is the crate lookup key),
  - every AA `mixedSet` weight resolves to a crate in its section (the invariant the
    runtime injection loop used to guarantee — now static data),
  - settings with a schema `choices` enum hold an allowed value.

Produces `Finding`s (errors block export; warnings do not), each an i18n key + params.
"""

from __future__ import annotations

from collections.abc import Collection
from dataclasses import dataclass, field
from typing import Any

from ctld_tools.catalog import Catalog
from ctld_tools.datamine import known_dcs_types
from ctld_tools.i18n import t
from ctld_tools.schema import Schema

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


def _iter_crates(catalog: Catalog):
    """Yield (section_name, entry) for every spawnableCrates entry."""
    sections = catalog.get("spawnableCrates") or {}
    for section_name, entries in sections.items():
        for entry in entries or []:
            yield section_name, entry


def _validate_crates(catalog: Catalog, types: set[str], out: list[Finding]) -> None:
    weights: dict[Any, str] = {}  # weight -> section (uniqueness)
    section_weights: dict[str, set] = {}  # section -> {weights present}

    for section, entry in _iter_crates(catalog):
        section_weights.setdefault(section, set())
        weight = entry.get("weight")
        unit = entry.get("unit")
        where = f"spawnableCrates.{section}[{entry.get('desc', weight)}]"

        # A weighted crate: known unit + unique weight.
        if weight is not None:
            if weight in weights:
                out.append(Finding(ERROR, where, "validate.crate.weight_collision", {"weight": weight}))
            weights[weight] = section
            section_weights[section].add(weight)
            # Repair crates (_repairFor) and mixedSets have no unit; only real crates do.
            if unit is not None and unit not in types:
                out.append(Finding(ERROR, where, "validate.crate.unknown_unit", {"unit": unit}))

    # mixedSet consistency: every referenced weight exists in the same section.
    for section, entry in _iter_crates(catalog):
        mixed = entry.get("mixedSet")
        if not mixed:
            continue
        where = f"spawnableCrates.{section}[{entry.get('desc', 'mixedSet')}]"
        for w in mixed:
            if w not in section_weights.get(section, set()):
                out.append(Finding(ERROR, where, "validate.mixedset.dangling_weight", {"weight": w}))


def _validate_choices(catalog: Catalog, schema: Schema, out: list[Finding]) -> None:
    for key in catalog.keys():
        choices = schema.choices(key)
        if not choices:
            continue
        value = catalog.get(key)
        if value is not None and value not in choices:
            out.append(
                Finding(
                    ERROR,
                    f"settings.{key}",
                    "validate.setting.bad_choice",
                    {"name": key, "value": value, "choices": ", ".join(map(str, choices))},
                )
            )


def validate(catalog: Catalog, schema: Schema, types: Collection[str] | None = None) -> list[Finding]:
    """Return findings for a complete catalogue against the DCS types + the schema."""
    resolved: set[str] = set(known_dcs_types()) if types is None else set(types)
    out: list[Finding] = []
    _validate_crates(catalog, resolved, out)
    _validate_choices(catalog, schema, out)
    return out


def has_errors(findings: list[Finding]) -> bool:
    return any(f.severity == ERROR for f in findings)
