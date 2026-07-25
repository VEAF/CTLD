"""Generate the embedded reference bundle from src/ (build-time, lupa).

The bundle is the slice of the CTLD default catalogue the runtime needs to resolve
and validate user-config targets by name — `spawnableCrates` (with AA crates injected)
and `loadableGroups`. It is committed as ctld_tools/data/reference.json and kept in
sync with src/ by a golden test, so `Reference.from_embedded()` works with no `src/`
and the MM .exe never imports lupa.
"""

from __future__ import annotations

import json
from importlib.resources import files
from pathlib import Path

BUNDLE_PATH = Path(str(files("ctld_tools").joinpath("data", "reference.json")))


def build_reference_bundle(src_dir: str | Path) -> dict:
    """Run src/CTLD_config.lua (lupa) and return the catalogue slice the runtime needs."""
    from ctld_tools.luaconfig import load_default_settings
    from ctld_tools.reference import load_setting_schema

    settings = load_default_settings(src_dir)
    scalar_settings = {k: v for k, v in settings.items() if isinstance(v, (bool, int, float, str))}
    return {
        "spawnableCrates": settings.get("spawnableCrates") or {},
        "loadableGroups": settings.get("loadableGroups") or [],
        "scalarSettings": scalar_settings,
        "settingSchema": load_setting_schema(src_dir),
    }


def write_reference(src_dir: str | Path, out_path: str | Path) -> None:
    bundle = build_reference_bundle(src_dir)
    text = json.dumps(bundle, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    Path(out_path).write_text(text, encoding="utf-8", newline="\n")
