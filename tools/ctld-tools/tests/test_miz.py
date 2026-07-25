"""Injecting a generated userConfig into a .miz: rank-1 MISSION START, idempotent, valid Lua."""

from pathlib import Path

from ctld_tools.miz import MARKER, inject_userconfig, read_mission
from ctld_tools.vendor import luadata

REPO = Path(__file__).resolve().parents[3]
MIZ = REPO / "missions" / "Test_CTLDNEXT_01.miz"


def test_injects_mission_start_trigger_at_rank1(tmp_path):
    out = tmp_path / "out.miz"
    inject_userconfig(MIZ, "ctld.numberOfTroops = 8", out)
    m = read_mission(out)
    assert m["trigrules"][1]["comment"] == MARKER
    assert m["trigrules"][1]["predicate"] == "triggerStart"
    assert m["trig"]["actions"][1].startswith("a_do_script")
    assert "numberOfTroops = 8" in m["trig"]["actions"][1]


def test_shifts_and_rewrites_existing_indices(tmp_path):
    out = tmp_path / "out.miz"
    n0 = len(read_mission(MIZ)["trig"]["actions"])
    inject_userconfig(MIZ, "-- x", out)
    m = read_mission(out)
    assert len(m["trig"]["actions"]) == n0 + 1
    # every shifted func self-reference matches its new key (in-code [idx] rewritten)
    for key, val in m["trig"]["func"].items():
        if isinstance(val, str) and "conditions[" in val:
            assert f"conditions[{key}]" in val


def test_generated_mission_round_trips(tmp_path):
    # No Lua runtime (lupa dropped in CTLD-TOOLS-CORE t05): the injected mission must
    # re-parse through the same luadata (de)serialization the .miz read/write relies on.
    out = tmp_path / "out.miz"
    inject_userconfig(MIZ, "ctld.slingLoad = true", out)
    m = read_mission(out)
    reparsed = luadata.unserialize(luadata.serialize(m, indent="\t"), keep_as_dict=["trig", "trigrules"])
    assert "slingLoad = true" in reparsed["trig"]["actions"][1]


def test_idempotent_reinjection(tmp_path):
    out1, out2 = tmp_path / "a.miz", tmp_path / "b.miz"
    inject_userconfig(MIZ, "-- first", out1)
    inject_userconfig(out1, "-- second", out2)
    m = read_mission(out2)
    markers = [r for r in m["trigrules"].values() if r.get("comment") == MARKER]
    assert len(markers) == 1
    assert "second" in m["trig"]["actions"][1]
