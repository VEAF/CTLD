"""Validate a complete config catalogue (the ADR-0011 model, not a diff).

Checks the whole `Catalog`:
  - every crate `unit` is a known DCS type (datamine),
  - crate `weight`s are globally unique (the weight is the crate lookup key),
  - every AA `mixedSet` weight resolves to a crate in its section (the invariant the
    runtime injection loop used to guarantee — now static data),
  - settings with a schema `choices` enum hold an allowed value,
  - every *parameter* is present (ADR 0011 Addendum 1) — see `_validate_completeness`.

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


# Settings holding a plain list of DCS type names, checked against the datamine. Unlike a
# crate `unit`, a name here is never spawned — it is matched against `getTypeName()` at init,
# so a typo produces no error at all, just a zone that never appears. This check is the only
# thing that catches it (the busted type lint is lenient by design and does not fail).
_TYPE_LIST_SETTINGS = ("logisticUnitTypes", "troopZoneShipTypes")


def _validate_type_lists(catalog: Catalog, types: set[str], out: list[Finding]) -> None:
    # A modded type is unknown to the datamine by definition; `modTypes` is where the mission
    # maker declares it, exactly as the schema promises.
    known = types | {t for t in (catalog.get("modTypes") or []) if isinstance(t, str)}
    for key in _TYPE_LIST_SETTINGS:
        for name in catalog.get(key) or []:
            if name not in known:
                out.append(
                    Finding(ERROR, f"settings.{key}", "validate.type_list.unknown_type", {"name": key, "type": name})
                )


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


def _validate_completeness(catalog: Catalog, default: Catalog, out: list[Finding]) -> None:
    """Every *parameter* must be present; a missing *list* is an intentional removal.

    ADR 0011 Addendum 1 splits the config in two tiers. A **parameter** — a key whose default
    value is a scalar — cannot be "removed": the engine needs a value to compute with, so an
    omission is an incomplete document. It survives at runtime (the engine falls back to the
    default and says so on screen) but it is not something to bless, so it blocks export. A
    **list** keeps ADR 0011 point 1: omitting it, or one of its elements, is deliberate.

    Keyed off the **default catalogue**, never the schema. `i18n_lang` is schema-declared but
    deliberately absent from the catalogue (see the comment in `CTLD_config_schema.yaml`), so a
    schema-driven rule would demand it and fail every valid config. The engine's tier rule reads
    the same document for the same reason, so the two layers cannot disagree.
    """
    for key in default.keys():
        value = default.get(key)
        if isinstance(value, (dict, list)):
            continue
        if not catalog.has(key):
            out.append(Finding(ERROR, f"settings.{key}", "validate.parameter.missing", {"name": key}))


def validate(
    catalog: Catalog,
    schema: Schema,
    types: Collection[str] | None = None,
    default: Catalog | None = None,
) -> list[Finding]:
    """Return findings for a complete catalogue against the DCS types + the schema.

    `default` is the reference catalogue the completeness check compares against; injected
    like `types` so this stays a pure function. When omitted the check is skipped.
    """
    resolved: set[str] = set(known_dcs_types()) if types is None else set(types)
    out: list[Finding] = []
    _validate_crates(catalog, resolved, out)
    _validate_type_lists(catalog, resolved, out)
    _validate_choices(catalog, schema, out)
    if default is not None:
        _validate_completeness(catalog, default, out)
    return out


def has_errors(findings: list[Finding]) -> bool:
    return any(f.severity == ERROR for f in findings)
