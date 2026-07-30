"""Embedded DCS type data, for offline validation and category lookups.

Generated (with tests/data/dcs_types.lua) from the pinned Quaggles datamine by
tools/dcs-data/gen_dcs_types.py, and bundled here so `validate` — and the packaged
ctld-tools.exe — can work without DCS or network.

The bundle maps each spawn type id to its datamine category (`Cars`, `Helicopters`,
`Planes`, …). The category is what lets the web app resolve the `spawnAs: AIR` authoring
convenience to the `AIRPLANE` or `HELICOPTER` the engine expects: DCS needs the right
`Group.Category` at spawn, and nothing in `src/` can ask for it.
"""

from __future__ import annotations

import json
from functools import lru_cache
from importlib.resources import files

# Datamine categories that spawn as aircraft, and the Group.Category each maps to. Anything
# else is a ground unit or a static as far as a crate is concerned.
_AIR_CATEGORIES = {
    "Helicopters": "HELICOPTER",
    "Planes": "AIRPLANE",
}


@lru_cache(maxsize=1)
def _types() -> dict[str, str]:
    """Every known spawn type id mapped to its datamine category."""
    data = files("ctld_tools").joinpath("data", "dcs_types.json").read_text(encoding="utf-8")
    return json.loads(data)


@lru_cache(maxsize=1)
def known_dcs_types() -> frozenset[str]:
    """Return the set of known DCS spawn type names."""
    return frozenset(_types())


def type_category(name: str) -> str | None:
    """The datamine category of a spawn type, or None if the type is unknown."""
    return _types().get(name)


def spawn_category(name: str) -> str:
    """Resolve a unit type to the `spawnAs` value the engine expects.

    `AIRPLANE` or `HELICOPTER` for aircraft, `GROUND` for everything else — including an
    unknown type, which `validate` reports separately rather than guessing about here.
    """
    return _AIR_CATEGORIES.get(type_category(name) or "", "GROUND")
