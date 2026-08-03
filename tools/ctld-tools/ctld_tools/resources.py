"""Locate the payloads the tool ships with: the catalogue, the schema, the engine, the sounds.

One resolver for all of them, because they travel together and are found the same way:

- **frozen** (the PyInstaller exe a Mission Maker double-clicks): every payload sits flat in
  `_MEIPASS/ctld_data`, put there by the `--add-data` entries in `release.yml`;
- **source checkout** (tests, `poetry run`): they live where the repository keeps them — the
  catalogue and the schema in `src/`, the built engine at the repo root, the sounds in `assets/`.

`CTLD_TOOLS_SRC` overrides the catalogue/schema directory; it predates the engine and the sounds and
keeps that narrower meaning.

Why the engine is bundled rather than downloaded (FEAT-ONE-CLICK-INSTALL): an exe then installs the
engine of *its own* release and nothing else, and it works with no network — a Mission Maker
configuring offline is the normal case, not the edge one.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

_ENV = "CTLD_TOOLS_SRC"

#: Beacon sounds the engine plays through `trigger.action.radioTransmission`. The names are the
#: `radioSound` / `radioSoundFC3` defaults; a mission without these files has silent beacons.
SOUND_NAMES = ("beacon.ogg", "beaconsilent.ogg")

ENGINE_NAME = "CTLD.lua"


def _frozen_dir() -> Path | None:
    """The bundle directory when running as the packaged exe, else None."""
    if getattr(sys, "frozen", False):
        return Path(getattr(sys, "_MEIPASS", ".")) / "ctld_data"
    return None


def _repo_root() -> Path:
    # ctld_tools/resources.py → tools/ctld-tools/ctld_tools → parents[3] is the repo root.
    return Path(__file__).resolve().parents[3]


def src_dir() -> Path:
    """The directory holding CTLD_config.yaml + CTLD_config_schema.yaml."""
    override = os.environ.get(_ENV)
    if override:
        return Path(override)
    return _frozen_dir() or (_repo_root() / "src")


def default_catalog_path() -> Path:
    return src_dir() / "CTLD_config.yaml"


def schema_path() -> Path:
    return src_dir() / "CTLD_config_schema.yaml"


def engine_path() -> Path:
    """The built `CTLD.lua`. A build artifact: absent from a fresh checkout."""
    return (_frozen_dir() or _repo_root()) / ENGINE_NAME


def sound_paths() -> list[Path]:
    """The beacon sound files, in `SOUND_NAMES` order."""
    base = _frozen_dir() or (_repo_root() / "assets")
    return [base / name for name in SOUND_NAMES]


def read_engine() -> bytes:
    """The engine's bytes.

    `CTLD.lua` is generated, never committed from a hand edit, so a checkout can legitimately not
    have one yet. Say what to run instead of serving nothing: an empty engine injected into a
    mission fails at mission start, far from here.
    """
    path = engine_path()
    if not path.is_file():
        raise FileNotFoundError(
            f"{ENGINE_NAME} not found at {path} — build it first: "
            "powershell -ExecutionPolicy Bypass -File tools\\build\\merge_CTLD.ps1"
        )
    return path.read_bytes()


def read_sounds() -> dict[str, bytes]:
    """The beacon sounds, keyed by file name."""
    out: dict[str, bytes] = {}
    for path in sound_paths():
        if not path.is_file():
            raise FileNotFoundError(f"beacon sound not found at {path}")
        out[path.name] = path.read_bytes()
    return out
