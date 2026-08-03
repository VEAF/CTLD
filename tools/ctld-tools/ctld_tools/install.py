"""Install CTLD into a `.miz`: the engine, the beacon sounds, the configuration, the triggers.

FEAT-ONE-CLICK-INSTALL. A Mission Maker downloads `ctld-tools.exe` and runs it; everything the
mission needs is bundled in the exe (see `resources.py`) and written here.

How DCS loads a script from a mission — the plumbing this module exists for, read out of VMCT's
mission builder (`mission_builder_worker.py`) rather than guessed at:

- the file goes in the archive under `l10n/DEFAULT/`;
- it gets an entry in `l10n/DEFAULT/mapResource`, a Lua table mapping a **resource key** to the file
  name (`{["CTLD_MapKey_Engine"] = "CTLD.lua"}`);
- the trigger action is `a_do_script_file(getValueResourceByKey("<key>"))` — `DO SCRIPT FILE` names
  a key, never a path.

**Sounds are different, and it matters**: `.ogg` files need *no* resource key. The engine plays them
by name through `trigger.action.radioTransmission("l10n/DEFAULT/beacon.ogg", …)`, so presence in
`l10n/DEFAULT/` is the whole requirement — VMCT's own code says the same, and warns that a sound
sitting anywhere else in the mission (`kneeboard/beacon.ogg`) is invisible to the scripts.

Order is not cosmetic: the configuration trigger must precede the engine trigger, because the engine
reads `ctld.configUser` as it loads.
"""

from __future__ import annotations

import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from ctld_tools import resources
from ctld_tools.miz import MARKER, read_mission, rebuild_triggers
from ctld_tools.vendor import luadata

#: Where DCS looks for mission-local scripts and sounds.
L10N = "l10n/DEFAULT"

#: The resource-map file inside the archive, and the Lua variable it assigns.
MAP_RESOURCE = f"{L10N}/mapResource"

ENGINE_FILE = "CTLD.lua"
CONFIG_FILE = "CTLD_userConfig.lua"

#: Resource keys we own. Stable across runs: re-installing overwrites the same entries instead of
#: leaving a second key pointing at the same file.
ENGINE_KEY = "CTLD_MapKey_Engine"
CONFIG_KEY = "CTLD_MapKey_UserConfig"

#: Trigger comments — how a re-install recognises what a previous run put there.
CONFIG_MARKER = MARKER
ENGINE_MARKER = "CTLD engine (ctld-tools)"


@dataclass
class InstallReport:
    """What an install wrote, so the caller can show it without reopening the archive."""

    miz: str
    engine_version: str | None = None
    files: list[str] = field(default_factory=list)
    triggers: list[str] = field(default_factory=list)
    replaced_previous: bool = False


def engine_version(engine: bytes) -> str | None:
    """Read `ctld.VERSION` out of the engine source, or None if it is not there."""
    import re

    match = re.search(rb'ctld\.VERSION\s*=\s*"([^"]+)"', engine)
    return match.group(1).decode("utf-8") if match else None


def _read_map_resource(miz_path: Path) -> dict:
    """The archive's resource map, or an empty one when the mission has never had a script."""
    with zipfile.ZipFile(miz_path) as z:
        if MAP_RESOURCE not in z.namelist():
            return {}
        text = z.read(MAP_RESOURCE).decode("utf-8")
    data = luadata.unserialize(text)
    return data if isinstance(data, dict) else {}


def _script_trigger(key: str, comment: str) -> dict:
    """A MISSION START `DO SCRIPT FILE` trigger, in both shapes DCS keeps it in.

    `trig` holds the compiled form the engine runs; `trigrules` holds the editor form. They must
    agree, or the Mission Editor rewrites one from the other and the trigger silently changes.
    """
    return {
        "trig": {
            "actions": f'a_do_script_file(getValueResourceByKey("{key}"));',
            "conditions": "return(true)",
            "flag": True,
        },
        "rule": {
            "rules": [],
            "eventlist": "",
            "actions": [{"predicate": "a_do_script_file", "file": key}],
            "predicate": "triggerStart",
            "comment": comment,
        },
    }


def install(miz_path: str | Path, userconfig_lua: str, out_path: str | Path | None = None) -> InstallReport:
    """Write the engine, the sounds, the configuration and their triggers into a `.miz`.

    Idempotent: a previous install's triggers (matched by comment), resource-map entries and files
    are replaced, never accumulated. `out_path` defaults to `miz_path` (in-place).
    """
    miz_path = Path(miz_path)
    out_path = Path(out_path) if out_path else miz_path

    engine = resources.read_engine()
    sounds = resources.read_sounds()

    mission = read_mission(miz_path)
    map_resource = _read_map_resource(miz_path)

    config = _script_trigger(CONFIG_KEY, CONFIG_MARKER)
    engine_trigger = _script_trigger(ENGINE_KEY, ENGINE_MARKER)

    # Configuration first: the engine reads ctld.configUser while loading.
    replaced = rebuild_triggers(
        mission,
        ours=[(config["trig"], config["rule"]), (engine_trigger["trig"], engine_trigger["rule"])],
        markers={CONFIG_MARKER, ENGINE_MARKER},
    )

    map_resource[CONFIG_KEY] = CONFIG_FILE
    map_resource[ENGINE_KEY] = ENGINE_FILE

    payload: dict[str, bytes] = {
        f"{L10N}/{ENGINE_FILE}": engine,
        f"{L10N}/{CONFIG_FILE}": userconfig_lua.encode("utf-8"),
        MAP_RESOURCE: ("mapResource = \n" + luadata.serialize(map_resource, indent="\t")).encode("utf-8"),
    }
    for name, data in sounds.items():
        payload[f"{L10N}/{name}"] = data

    _write_miz(mission, miz_path, out_path, payload)

    return InstallReport(
        miz=out_path.name,
        engine_version=engine_version(engine),
        files=[ENGINE_FILE, CONFIG_FILE, *sorted(sounds)],
        triggers=["configuration", "engine"],
        replaced_previous=replaced,
    )


def _write_miz(mission: dict, in_path: Path, out_path: Path, payload: dict[str, bytes]) -> None:
    """Rewrite the archive with a new `mission` plus every entry of `payload`.

    Entries in `payload` replace same-named ones rather than being appended: a zip may legally hold
    two members with one name, and DCS reads whichever it finds first — which would make a
    re-install look like it did nothing.
    """
    body = ("mission = \n" + luadata.serialize(mission, indent="\t")).encode("utf-8")
    replaced = {"mission", *payload}
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    with zipfile.ZipFile(in_path) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename not in replaced:
                zout.writestr(item, zin.read(item.filename))
        zout.writestr("mission", body)
        for name, data in payload.items():
            zout.writestr(name, data)
    tmp.replace(out_path)
