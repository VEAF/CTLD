"""Emit the engine defaults as a language-neutral JSON oracle.

The busted round-trip parity test needs an independent reference to compare against
`CTLDConfig.parseYAML(ctld.configDefault)`. Since ADR 0011 dropped the Python-emitted
Lua defaults table, that reference is now this JSON, produced by the core (ruamel) and
committed for the test to load. It is the flat settings namespace: the `mm_facing` and
`advanced` readability sections merged, plus any top-level keys (e.g. `configVersion`) —
mirroring the merge `CTLDConfig:load()` performs at runtime.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ruamel.yaml import YAML

_SECTIONS = ("mm_facing", "advanced")


def flat_defaults(yaml_path: str | Path) -> dict[str, Any]:
    """Read a config YAML and return its settings flattened across the sections."""
    yaml = YAML(typ="safe")
    doc = yaml.load(Path(yaml_path).read_text(encoding="utf-8"))
    if not isinstance(doc, dict):
        raise ValueError("config YAML did not parse to a mapping")
    merged: dict[str, Any] = {}
    for section in _SECTIONS:
        merged.update(doc.get(section) or {})
    for key, value in doc.items():
        if key not in _SECTIONS:
            merged[key] = value
    return merged


def write_json(yaml_path: str | Path, out_path: str | Path) -> None:
    """Write the flat defaults as deterministic, pretty JSON (the committed oracle)."""
    data = flat_defaults(yaml_path)
    text = json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    Path(out_path).write_text(text, encoding="utf-8", newline="\n")
