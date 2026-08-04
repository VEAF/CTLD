"""Installing CTLD into a `.miz`: engine, sounds, configuration, triggers — idempotently.

FEAT-ONE-CLICK-INSTALL ticket 02, plus FIX-INSTALL-SOUND-ORPHANS. The plumbing under test was read
out of VMCT's mission builder: a script needs a `mapResource` entry and is loaded by resource **key**.
A `.ogg` needs no key to be *played* — the engine passes a name to `radioTransmission` — but it needs
one to *survive*: the Mission Editor drops files no trigger refers to when it saves the mission.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from ctld_tools import resources
from ctld_tools.embed import wrap
from ctld_tools.install import (
    CONFIG_FILE,
    CONFIG_KEY,
    CONFIG_MARKER,
    ENGINE_FILE,
    ENGINE_KEY,
    ENGINE_MARKER,
    L10N,
    MAP_RESOURCE,
    SILENT_COUNTRIES,
    SOUND_KEYS,
    SOUNDS_MARKER,
    _mission_countries,
    _silent_country,
    engine_version,
    install,
    read_config,
)
from ctld_tools.miz import inject_userconfig, read_mission
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


def test_every_payload_gets_a_resource_key(tmp_path):
    """Scripts *and* sounds get a key of ours — reported by David: the sounds vanished.

    A `.ogg` needs no key to be *played* (the engine passes a name to `radioTransmission`), which is
    why the first version of this installer added none. But an unreferenced file is an orphan the
    Mission Editor drops when it saves the mission, and beacons then go silent with nothing to show
    why. The key, plus the preload trigger below, is what makes the file part of the mission.

    The test mission already maps `beacon.ogg` under the editor's own `ResKey_Action_10`; ours is a
    separate, stably-named key, so compare what the install *added*.
    """
    out = tmp_path / "out.miz"
    before = map_resource(MIZ)
    install(MIZ, CONFIG, out)

    resmap = map_resource(out)
    assert resmap[CONFIG_KEY] == CONFIG_FILE
    assert resmap[ENGINE_KEY] == ENGINE_FILE

    added = {k: v for k, v in resmap.items() if k not in before}
    assert added == {
        CONFIG_KEY: CONFIG_FILE,
        ENGINE_KEY: ENGINE_FILE,
        SOUND_KEYS["beacon.ogg"]: "beacon.ogg",
        SOUND_KEYS["beaconsilent.ogg"]: "beaconsilent.ogg",
    }


def test_a_mission_start_trigger_references_each_sound(tmp_path):
    """The reference is the point: without it the editor treats the .ogg as an orphan.

    Shape copied from real missions (`a_out_sound_c(<country>, getValueResourceByKey(key), 0)`), and
    asserted in both places DCS keeps a trigger — a `trig`/`trigrules` mismatch makes the editor
    rewrite one from the other.
    """
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)
    m = read_mission(out)

    assert m["trigrules"][3]["comment"] == SOUNDS_MARKER
    assert m["trigrules"][3]["predicate"] == "triggerStart"

    country = _silent_country(m)
    compiled = m["trig"]["actions"][3]
    editor = m["trigrules"][3]["actions"]
    for rank, name in enumerate(("beacon.ogg", "beaconsilent.ogg"), start=1):
        key = SOUND_KEYS[name]
        assert f'a_out_sound_c({country}, getValueResourceByKey("{key}"), 0);' in compiled
        assert editor[rank] == {
            "predicate": "a_out_sound_c",
            "countrylist": country,
            "file": key,
            "start_delay": 0,
        }


def test_the_preload_plays_to_a_country_the_mission_does_not_use(tmp_path):
    """Otherwise players hear a beacon tone at mission start — the reason for the whole idiom.

    The README states the rule for a hand-made install ("pick an unused country"); picking a fixed one
    in code would be a bet against the mission, so the mission is read and an absent id chosen.
    """
    out = tmp_path / "out.miz"
    install(MIZ, CONFIG, out)
    m = read_mission(out)

    used = _mission_countries(m)
    assert used, "the fixture mission declares countries, or this test proves nothing"
    assert _silent_country(m) not in used


def test_a_taken_preferred_country_is_skipped():
    """Peru first, Australia next, then any free id — never one the mission actually uses."""
    assert _silent_country({}) == SILENT_COUNTRIES[0]

    def mission_with(*ids):
        return {"coalition": {"blue": {"country": [{"id": i, "name": str(i)} for i in ids]}}}

    assert _silent_country(mission_with(89)) == SILENT_COUNTRIES[1]
    assert _silent_country(mission_with(89, 21)) not in (89, 21)


def test_installing_into_a_mission_with_no_sounds_writes_them(tmp_path):
    """The reported case: a mission that never carried a beacon sound.

    Built by stripping the test mission, because that is what a Mission Maker starts from — the
    fixture mission happens to carry both sounds already, which would hide a regression here.
    """
    bare = tmp_path / "bare.miz"
    with zipfile.ZipFile(MIZ) as zin, zipfile.ZipFile(bare, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename.endswith(".ogg"):
                continue
            data = zin.read(item.filename)
            if item.filename == MAP_RESOURCE:
                kept = [line for line in data.decode("utf-8").splitlines() if ".ogg" not in line]
                data = "\n".join(kept).encode("utf-8")
            zout.writestr(item, data)

    out = tmp_path / "out.miz"
    install(bare, CONFIG, out)

    entries = names(out)
    resmap = map_resource(out)
    for name in ("beacon.ogg", "beaconsilent.ogg"):
        assert f"{L10N}/{name}" in entries
        assert resmap[SOUND_KEYS[name]] == name


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

    # Three of ours: configuration, engine, sound preload.
    assert len(m["trig"]["actions"]) == n0 + 3
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
    assert report.triggers == ["configuration", "engine", "sounds"]
    assert report.engine_version == engine_version(resources.read_engine())
    assert report.engine_version and report.engine_version[0].isdigit()


def test_installing_in_place_is_allowed(tmp_path):
    target = tmp_path / "inplace.miz"
    target.write_bytes(MIZ.read_bytes())

    install(target, CONFIG)

    assert f"{L10N}/{ENGINE_FILE}" in names(target)


# ── Reading a configuration back out of a mission (ticket 03) ────────────────────────
# Two storage shapes exist in the wild: the file this tool writes now, and the inline trigger
# rc1–rc3 wrote. Both must be readable, or a mission configured last month can only be redone
# from scratch — its settings are in the file, just unreachable.


def test_reads_back_the_configuration_it_installed(tmp_path):
    out = tmp_path / "out.miz"
    yaml = "mm_facing:\n  slingLoad: true\n  numberOfTroops: 8\n"
    install(MIZ, wrap(yaml, "configUser"), out)

    found = read_config(out)
    assert found is not None
    assert found.shape == "file"
    assert found.yaml == yaml


def test_reads_back_a_configuration_injected_by_rc1_to_rc3(tmp_path):
    """The old injector wrote the snapshot into a trigger; those missions must still open."""
    out = tmp_path / "old.miz"
    yaml = "mm_facing:\n  slingLoad: false\n"
    inject_userconfig(MIZ, wrap(yaml, "configUser"), out)

    found = read_config(out)
    assert found is not None
    assert found.shape == "inline"
    assert found.yaml == yaml


def test_a_mission_with_no_ctld_config_reads_as_nothing():
    """Not an error: that is what a first install looks like."""
    assert read_config(MIZ) is None


@pytest.mark.parametrize(
    "payload",
    [
        "mm_facing:\n  note: 'closing ]] inside'\n",
        "mm_facing:\n  note: 'and ]==] too'\n",
        "mm_facing:\n  note: '-- looks like a comment'\n",
        "mm_facing:\n  note: 'a ]=] and a ]] and a ]===]'\n",
    ],
)
def test_the_yaml_survives_delimiters_that_break_a_naive_regex(tmp_path, payload):
    """`wrap` picks the bracket level from the content, so `unwrap` must find the matching one."""
    out = tmp_path / "brackets.miz"
    install(MIZ, wrap(payload, "configUser"), out)

    found = read_config(out)
    assert found is not None and found.yaml == payload


def test_round_trip_install_read_install_is_stable(tmp_path):
    first, second = tmp_path / "a.miz", tmp_path / "b.miz"
    yaml = "mm_facing:\n  slingLoad: true\n"
    install(MIZ, wrap(yaml, "configUser"), first)

    found = read_config(first)
    assert found is not None
    install(first, wrap(found.yaml, "configUser"), second)

    assert read_config(second) == found


def test_the_session_opens_a_miz_like_a_yaml(tmp_path):
    """The tool's "open" path accepts a mission, and remembers which one."""
    from ctld_tools.web.state import Session

    out = tmp_path / "session.miz"
    install(MIZ, wrap("mm_facing:\n  numberOfTroops: 12\n", "configUser"), out)

    session = Session()
    session.load_path(out)

    assert session.catalog.get("numberOfTroops") == 12
    assert session.mission_path == out
    assert session.config_shape == "file"


def test_opening_a_mission_without_a_configuration_says_so(tmp_path):
    from ctld_tools.web.state import Session

    with pytest.raises(ValueError, match="no CTLD configuration"):
        Session().load_path(MIZ)
