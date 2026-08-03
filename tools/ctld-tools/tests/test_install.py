"""Installing CTLD into a `.miz`: engine, sounds, configuration, triggers — idempotently.

FEAT-ONE-CLICK-INSTALL ticket 02. The plumbing under test was read out of VMCT's mission builder:
a script needs a `mapResource` entry and is loaded by resource **key**, while a `.ogg` needs no
entry at all and is found by name in `l10n/DEFAULT/`.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from ctld_tools import resources
from ctld_tools.install import (
    CONFIG_FILE,
    CONFIG_KEY,
    CONFIG_MARKER,
    ENGINE_FILE,
    ENGINE_KEY,
    ENGINE_MARKER,
    L10N,
    MAP_RESOURCE,
    engine_version,
    install,
)
from ctld_tools.miz import read_mission
from ctld_tools.vendor import luadata

REPO = Path(__file__).resolve().parents[3]
MIZ = REPO / "missions" / "Test_CTLDNEXT_01.miz"

pytestmark = pytest.mark.skipif(not (REPO / "CTLD.lua").is_file(), reason="CTLD.lua not built in this checkout")

CONFIG = "ctld = ctld or {}\nctld.configUser = [==[\nmm_facing:\n  slingLoad: true\n]==]\n"


def names(miz: Path) -> list[str]:
    with zipfile.ZipFile(miz) as z:
        return z.namelist()


def map_resource(miz: Path) -> dict:
    with zipfile.ZipFile(miz) as z:
        return luadata.unserialize(z.read(MAP_RESOURCE).decode("utf-8"))


def test_every_payload_lands_in_l10n(tmp_path):
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)

    entries = names(out)
    for name in (ENGINE_FILE, CONFIG_FILE, "beacon.ogg", "beaconsilent.ogg"):
        assert f"{L10N}/{name}" in entries, f"{name} not written into the mission"


def test_the_engine_is_the_bundled_one_byte_for_byte(tmp_path):
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)
    with zipfile.ZipFile(out) as z:
        assert z.read(f"{L10N}/{ENGINE_FILE}") == resources.read_engine()


def test_scripts_get_a_resource_key_and_sounds_do_not(tmp_path):
    """A .ogg is played by name; only scripts are loaded through getValueResourceByKey.

    Careful with the assertion: a mission may already map its sounds — the test mission carries
    `ResKey_Action_10 = "beacon.ogg"`, put there by a DCS sound action. That is the *editor's* key
    for its own trigger, unrelated to how CTLD reads the file. What must hold is that **we** add no
    key for a sound, so compare the map before and after.
    """
    out = tmp_path / "out.miz"
    before = map_resource(MIZ)
    install(MIZ, CONFIG, out)

    resmap = map_resource(out)
    assert resmap[CONFIG_KEY] == CONFIG_FILE
    assert resmap[ENGINE_KEY] == ENGINE_FILE

    added = {k: v for k, v in resmap.items() if k not in before}
    assert added == {CONFIG_KEY: CONFIG_FILE, ENGINE_KEY: ENGINE_FILE}, "only scripts get a key"


def test_configuration_runs_before_the_engine(tmp_path):
    """The engine reads ctld.configUser as it loads, so rank order is behaviour, not style."""
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)
    m = read_mission(out)

    assert m["trigrules"][1]["comment"] == CONFIG_MARKER
    assert m["trigrules"][2]["comment"] == ENGINE_MARKER
    assert f'getValueResourceByKey("{CONFIG_KEY}")' in m["trig"]["actions"][1]
    assert f'getValueResourceByKey("{ENGINE_KEY}")' in m["trig"]["actions"][2]


def test_both_trigger_shapes_agree(tmp_path):
    """`trig` is what runs, `trigrules` is what the editor shows; a mismatch rewrites one silently."""
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)
    m = read_mission(out)

    for rank, key in ((1, CONFIG_KEY), (2, ENGINE_KEY)):
        # luadata keeps the action list as a 1-based Lua table, not a Python list.
        assert m["trigrules"][rank]["actions"][1] == {"predicate": "a_do_script_file", "file": key}
        assert m["trigrules"][rank]["predicate"] == "triggerStart"
        assert m["trig"]["conditions"][rank] == "return(true)"
        assert m["trig"]["funcStartup"][rank] == (
            f"if mission.trig.conditions[{rank}]() then mission.trig.actions[{rank}]() end"
        )


def test_existing_triggers_survive_with_rewritten_indices(tmp_path):
    out = tmp_path / "out.miz"
    n0 = len(read_mission(MIZ)["trig"]["actions"])
    install(MIZ, CONFIG, out)
    m = read_mission(out)

    assert len(m["trig"]["actions"]) == n0 + 2
    for key, val in m["trig"]["func"].items():
        if isinstance(val, str) and "conditions[" in val:
            assert f"conditions[{key}]" in val


def test_installing_twice_replaces_and_does_not_accumulate(tmp_path):
    first, second = tmp_path / "a.miz", tmp_path / "b.miz"
    report1 = install(MIZ, CONFIG, first)
    report2 = install(first, CONFIG.replace("slingLoad: true", "slingLoad: false"), second)

    m = read_mission(second)
    assert [r.get("comment") for r in m["trigrules"].values()].count(CONFIG_MARKER) == 1
    assert [r.get("comment") for r in m["trigrules"].values()].count(ENGINE_MARKER) == 1
    assert len(m["trig"]["actions"]) == len(read_mission(first)["trig"]["actions"])

    # One member per name: a zip may hold duplicates and DCS reads the first it finds.
    entries = names(second)
    for name in (ENGINE_FILE, CONFIG_FILE, "beacon.ogg"):
        assert entries.count(f"{L10N}/{name}") == 1
    assert entries.count(MAP_RESOURCE) == 1

    with zipfile.ZipFile(second) as z:
        assert b"slingLoad: false" in z.read(f"{L10N}/{CONFIG_FILE}")

    assert report1.replaced_previous is False
    assert report2.replaced_previous is True


def test_a_pre_existing_resource_map_is_preserved(tmp_path):
    """A mission with its own scripts keeps them: we add keys, we do not own the map."""
    seeded = tmp_path / "seeded.miz"
    with zipfile.ZipFile(MIZ) as zin, zipfile.ZipFile(seeded, "w") as zout:
        for item in zin.infolist():
            if item.filename != MAP_RESOURCE:
                zout.writestr(item, zin.read(item.filename))
        zout.writestr(MAP_RESOURCE, 'mapResource = \n{["OTHER_MapKey"] = "other.lua"}')

    out = tmp_path / "out.miz"
    install(seeded, CONFIG, out)

    resmap = map_resource(out)
    assert resmap["OTHER_MapKey"] == "other.lua"
    assert resmap[ENGINE_KEY] == ENGINE_FILE


def test_a_mission_with_no_resource_map_gets_one(tmp_path):
    bare = tmp_path / "bare.miz"
    with zipfile.ZipFile(MIZ) as zin, zipfile.ZipFile(bare, "w") as zout:
        for item in zin.infolist():
            if item.filename != MAP_RESOURCE:
                zout.writestr(item, zin.read(item.filename))
    assert MAP_RESOURCE not in names(bare)

    out = tmp_path / "out.miz"
    install(bare, CONFIG, out)

    assert map_resource(out)[ENGINE_KEY] == ENGINE_FILE


def test_the_mission_still_round_trips(tmp_path):
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)
    m = read_mission(out)
    reparsed = luadata.unserialize(luadata.serialize(m, indent="\t"), keep_as_dict=["trig", "trigrules"])
    assert f'getValueResourceByKey("{ENGINE_KEY}")' in reparsed["trig"]["actions"][2]


def test_the_report_says_what_was_written(tmp_path):
    out = tmp_path / "out.miz"
    report = install(MIZ, CONFIG, out)

    assert report.miz == "out.miz"
    assert report.files == [ENGINE_FILE, CONFIG_FILE, "beacon.ogg", "beaconsilent.ogg"]
    assert report.triggers == ["configuration", "engine"]
    assert report.engine_version == engine_version(resources.read_engine())
    assert report.engine_version and report.engine_version[0].isdigit()


def test_installing_in_place_is_allowed(tmp_path):
    target = tmp_path / "inplace.miz"
    target.write_bytes(MIZ.read_bytes())

    install(target, CONFIG)

    assert f"{L10N}/{ENGINE_FILE}" in names(target)
