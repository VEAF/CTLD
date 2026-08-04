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

**Sounds need the same plumbing, for a different reason.** At *runtime* an `.ogg` needs no resource
key: the engine plays it by name through `trigger.action.radioTransmission("l10n/DEFAULT/beacon.ogg",
…)`, so presence in `l10n/DEFAULT/` is enough — and VMCT warns that a sound sitting anywhere else in
the mission (`kneeboard/beacon.ogg`) is invisible to the scripts. But a file no trigger refers to is
an **orphan**: open the mission in the Mission Editor, save it, and the editor rewrites the archive
from its own model and drops it. The beacons then go silent with nothing to show why, which is the
exact failure this whole module exists to prevent.

So each sound also gets a resource key plus a MISSION START action referencing it — the "sound
preload" idiom, which this repo's README already documents for a hand-made install: *"pick an unused
country like Australia so no player hears them at mission start"*. That is exactly what `_sound_trigger`
does, through `a_out_sound_c(<country>, …)` — 1274 such actions across 491 real VEAF missions. The
country is chosen per mission, among those the mission does not declare, so the sound reaches nobody.

Order is not cosmetic: the configuration trigger must precede the engine trigger, because the engine
reads `ctld.configUser` as it loads.
"""

from __future__ import annotations

import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from ctld_tools import resources
from ctld_tools.embed import unwrap
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

#: One resource key per beacon sound, keyed by file name. Present so the Mission Editor keeps the
#: files (see the module docstring): a sound no trigger refers to is dropped on the next save.
SOUND_KEYS = {name: f"CTLD_MapKey_Sound_{name.split('.')[0]}" for name in resources.SOUND_NAMES}

#: Trigger comments — how a re-install recognises what a previous run put there.
CONFIG_MARKER = MARKER
ENGINE_MARKER = "CTLD engine (ctld-tools)"
SOUNDS_MARKER = "CTLD beacon sounds (ctld-tools)"


@dataclass
class FoundConfig:
    """A configuration read back out of a mission, and which shape it was stored in.

    `shape` is `"file"` for an install by this tool, `"inline"` for one by rc1–rc3 — the tool used to
    write the whole snapshot into a trigger. Worth surfacing: an inline mission is about to be
    upgraded to the file shape the next time it is installed.
    """

    yaml: str
    shape: str


def read_config(miz_path: str | Path) -> FoundConfig | None:
    """The CTLD configuration a mission carries, or None when it has none.

    Reads both shapes. The file shape is a zip member; the inline shape is the snapshot the old
    injector wrote into a trigger, which is why this looks in `trigrules` — the editor form keeps the
    script's **text**, unescaped, while `trig` holds it escaped inside compiled Lua.
    """
    miz_path = Path(miz_path)

    with zipfile.ZipFile(miz_path) as z:
        if f"{L10N}/{CONFIG_FILE}" in z.namelist():
            lua = z.read(f"{L10N}/{CONFIG_FILE}").decode("utf-8")
            yaml = unwrap(lua, "configUser")
            if yaml is not None:
                return FoundConfig(yaml=yaml, shape="file")

    mission = read_mission(miz_path)
    for rule in (mission.get("trigrules") or {}).values():
        if not isinstance(rule, dict) or rule.get("comment") != CONFIG_MARKER:
            continue
        for action in (rule.get("actions") or {}).values():
            if isinstance(action, dict) and isinstance(action.get("text"), str):
                yaml = unwrap(action["text"], "configUser")
                if yaml is not None:
                    return FoundConfig(yaml=yaml, shape="inline")
    return None


@dataclass
class InstallReport:
    """What an install wrote, so the caller can show it without reopening the archive."""

    miz: str
    engine_version: str | None = None
    files: list[str] = field(default_factory=list)
    triggers: list[str] = field(default_factory=list)
    replaced_previous: bool = False


def engine_version(engine: bytes) -> str | None:
    """The `ctld.VERSION` of the engine being installed.

    Reads the bytes actually written into the mission rather than asking `resources.ctld_version()`:
    the report must describe what landed, not what the tool believes it carries.
    """
    return resources.version_from(engine)


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


#: Countries to address the preload trigger to, most preferred first, used only when the mission has
#: no unit of that country. Peru is the VEAF mission set's de-facto choice for a sound nobody should
#: hear (363 of the 1274 `a_out_sound_c` uses across 491 missions); Australia is the one this repo's
#: README names. Ids from the DCS datamine country table, not from memory.
SILENT_COUNTRIES = (89, 21)


def _mission_countries(mission: dict) -> set[int]:
    """Every country id the mission declares, across all coalitions.

    `country` comes back as a Lua table, which luadata renders as a list or a dict depending on
    whether its keys are contiguous — both shapes occur, so both are read.
    """
    found: set[int] = set()
    for side in (mission.get("coalition") or {}).values():
        countries = (side or {}).get("country")
        entries = countries.values() if isinstance(countries, dict) else (countries or [])
        for entry in entries:
            if isinstance(entry, dict) and isinstance(entry.get("id"), int):
                found.add(entry["id"])
    return found


def _silent_country(mission: dict) -> int:
    """A country id this mission does not use, so the preload plays to nobody.

    Picking a fixed country would be a bet: address the sound to one that *is* in the mission and its
    players hear a beacon tone at mission start. So the mission is read first, and the id is chosen
    among those it does not declare — the preferred two first, then any free id.
    """
    used = _mission_countries(mission)
    for candidate in SILENT_COUNTRIES:
        if candidate not in used:
            return candidate
    # 92 countries in the datamine table; a mission using every one of them is not a real case, but
    # returning a used id silently would be, so fall back to the last one rather than to nothing.
    return next((cid for cid in range(92) if cid not in used), SILENT_COUNTRIES[0])


def _sound_trigger(keys: list[str], comment: str, country: int) -> dict:
    """A MISSION START trigger playing each sound to a country the mission does not use.

    The point is the *reference*, not the playback: `mapResource` plus a trigger action is what makes
    the Mission Editor treat an `.ogg` as part of the mission instead of an orphan to drop on save.
    Addressing it to an empty country is what keeps it silent — the idiom this repo's README already
    documents for a hand-made install ("pick an unused country like Australia so no player hears them
    at mission start"), and which 1274 `a_out_sound_c` actions across 491 real missions use.

    Shape copied from those missions rather than guessed: `a_out_sound_c(<country>, resource, delay)`
    compiled, `countrylist` in the editor form.
    """
    return {
        "trig": {
            "actions": "".join(f'a_out_sound_c({country}, getValueResourceByKey("{key}"), 0);' for key in keys),
            "conditions": "return(true)",
            "flag": True,
        },
        "rule": {
            "rules": [],
            "eventlist": "",
            "actions": [
                {"predicate": "a_out_sound_c", "countrylist": country, "file": key, "start_delay": 0} for key in keys
            ],
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
    sound_keys = [SOUND_KEYS[name] for name in sorted(sounds)]
    sounds_trigger = _sound_trigger(sound_keys, SOUNDS_MARKER, _silent_country(mission))

    # Configuration first: the engine reads ctld.configUser while loading. The sounds last: their
    # trigger exists to hold a reference, and nothing depends on when it runs.
    replaced = rebuild_triggers(
        mission,
        ours=[
            (config["trig"], config["rule"]),
            (engine_trigger["trig"], engine_trigger["rule"]),
            (sounds_trigger["trig"], sounds_trigger["rule"]),
        ],
        markers={CONFIG_MARKER, ENGINE_MARKER, SOUNDS_MARKER},
    )

    map_resource[CONFIG_KEY] = CONFIG_FILE
    map_resource[ENGINE_KEY] = ENGINE_FILE
    for name in sorted(sounds):
        map_resource[SOUND_KEYS[name]] = name

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
        triggers=["configuration", "engine", "sounds"],
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
