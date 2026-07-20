"""Embedded DCS type-name set, for offline validation of user-config `unit` fields.

The set is generated (with tests/data/dcs_types.lua) from the pinned Quaggles
datamine by tools/dcs-data/gen_dcs_types.py, and bundled here so `validate` — and
the packaged ctld-tools.exe — can check unit names without DCS or network.
"""

from __future__ import annotations

import json
from functools import lru_cache
from importlib.resources import files


@lru_cache(maxsize=1)
def known_dcs_types() -> frozenset[str]:
    """Return the set of known DCS spawn type names."""
    data = files("ctld_tools").joinpath("data", "dcs_types.json").read_text(encoding="utf-8")
    return frozenset(json.loads(data))
