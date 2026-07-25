"""Positional zone field schemas (ported from FullGas's reference.py `_ZONE_FIELD_SCHEMAS`).

troopZones / wpZones / AIZones are stored as positional Lua arrays; these schemas name each
position so the web editor can present named fields. The frontend does the positional↔named
conversion; the backend only exposes the layout.
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
    "AIZones": [
        {"name": "zoneName", "pos": 0, "type": "str"},
        {"name": "mode", "pos": 1, "type": "str"},
        {"name": "side", "pos": 2, "type": "int"},
    ],
}
