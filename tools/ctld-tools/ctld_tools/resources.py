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
import re
import sys
from pathlib import Path

_ENV = "CTLD_TOOLS_SRC"

#: Beacon sounds the engine plays through `trigger.action.radioTransmission`. The names are the
#: `radioSound` / `radioSoundFC3` defaults; a mission without these files has silent beacons.
SOUND_NAMES = ("beacon.ogg", "beaconsilent.ogg")

#: The two settings that name a beacon sound, each with the bundled file it points at by default,
#: the name a **customised** file takes inside a mission, and the label recording what that file
#: was called on the Mission Maker's disk.
#:
#: The reserved name is the whole of ADR 0012: it is what tells the tool, on reopening a mission,
#: that this sound is not the bundled one — without a second configuration key that could
#: contradict the engine. Comparing against the default name instead would misread the ordinary
#: case of a Mission Maker whose own file is called `beacon.ogg`.
SOUND_SETTINGS: dict[str, dict[str, str]] = {
    "radioSound": {
        "default": "beacon.ogg",
        "custom": "CTLD_beacon_custom.ogg",
        "label": "radioSoundOriginalName",
    },
    "radioSoundFC3": {
        "default": "beaconsilent.ogg",
        "custom": "CTLD_beaconsilent_custom.ogg",
        "label": "radioSoundFC3OriginalName",
    },
}

#: Every beacon-sound file name this tool owns — the two bundled ones and the two reserved custom
#: ones. Nothing outside this set is ever touched in a Mission Maker's archive.
OWNED_SOUND_NAMES = frozenset(
    [*(s["default"] for s in SOUND_SETTINGS.values()), *(s["custom"] for s in SOUND_SETTINGS.values())]
)

#: The first four bytes of any Ogg stream. Checked when a file is chosen: renaming an `.mp3` to
#: `.ogg` takes two seconds, DCS then plays nothing, and the Mission Maker finds out in flight.
OGG_MAGIC = b"OggS"


def is_ogg(data: bytes) -> bool:
    return data[:4] == OGG_MAGIC


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


#: `ctld.VERSION = "x.y.z[-rcN]"` — the same pattern `merge_CTLD.ps1` uses to stamp the build, kept
#: loose on purpose so a pre-release suffix survives.
_VERSION_RE = re.compile(rb'ctld\.VERSION\s*=\s*"([^"]+)"')

UNKNOWN_VERSION = "unknown"


def version_from(source: bytes | str) -> str | None:
    """The `ctld.VERSION` declared in a chunk of Lua, or None."""
    data = source.encode("utf-8") if isinstance(source, str) else source
    match = _VERSION_RE.search(data)
    return match.group(1).decode("utf-8") if match else None


def ctld_version() -> str:
    """The CTLD version this build belongs to.

    **One source of truth: `ctld.VERSION`.** Not a number in `pyproject.toml` maintained by hand —
    that is how the packaging version drifted to `0.1.0` and stayed there while CTLD reached 2.0.0.
    The tool ships with an engine, so it reads the version out of it; from a source checkout with no
    built engine it falls back to `src/CTLD_config.lua`, which is where the build reads it too.
    """
    engine = engine_path()
    if engine.is_file():
        found = version_from(engine.read_bytes())
        if found:
            return found
    config = src_dir() / "CTLD_config.lua"
    if config.is_file():
        found = version_from(config.read_bytes())
        if found:
            return found
    # A checkout with neither is possible (someone running the tool from a partial tree); say so
    # rather than invent a number that would end up in an install report.
    return UNKNOWN_VERSION


def docs_version(version: str | None = None) -> str:
    """The documentation version to link to for `version` (default: this build's).

    A pre-release has no published documentation of its own — `mike deploy` only runs for a tag, and
    the notes for an rc are the `dev` pages. So any `-rc` maps to `dev`, and a stable maps to itself.
    The rule needs no maintenance: the day a stable is tagged and its documentation published, the
    link follows without a code change.
    """
    resolved = version or ctld_version()
    if resolved == UNKNOWN_VERSION or "-" in resolved:
        return "dev"
    return resolved
