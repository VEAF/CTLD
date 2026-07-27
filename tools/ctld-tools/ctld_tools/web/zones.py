"""Positional zone field schemas (ported from FullGas's reference.py `_ZONE_FIELD_SCHEMAS`).

troopZones / wpZones are stored as positional Lua arrays; these schemas name each position so the
web editor can present named fields. The frontend does the positional↔named conversion; the backend
only exposes the layout.

`AIZones` used to be listed here. Nothing in `src/` ever read that key — the engine reads `aiZones`
(lowercase), whose entries are named records, not positional arrays — so the schema described a
format no code consumed, and described it wrongly (3 fields for the 5 positions the catalogue
shipped). Both the key and this schema are gone; `aiZones` is documented in
`CTLD_config_schema.yaml`.
"""

from __future__ import annotations

from typing import Any

ZONE_FIELD_SCHEMAS: dict[str, list[dict[str, Any]]] = {
    "troopZones": [
        {"name": "zoneName", "pos": 0, "type": "str"},
        {"name": "colour", "pos": 1, "type": "str", "choices": ["blue", "red", "green", "orange", "none"]},
        {"name": "troopLimit", "pos": 2, "type": "int"},
        {"name": "canPickup", "pos": 3, "type": "str", "choices": ["yes", "no"]},
        {"name": "groupSize", "pos": 4, "type": "int"},
        {"name": "iconId", "pos": 5, "type": "int", "optional": True},
    ],
    "wpZones": [
        {"name": "zoneName", "pos": 0, "type": "str"},
        {"name": "colour", "pos": 1, "type": "str", "choices": ["blue", "red", "green", "orange", "none"]},
        {"name": "canPickup", "pos": 2, "type": "str", "choices": ["yes", "no"]},
        {"name": "side", "pos": 3, "type": "int"},
    ],
}
