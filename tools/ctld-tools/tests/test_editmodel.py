"""The edit model holds the user-config state and all logic, free of any UI.

Each operation mutates the state and re-runs live validation; generation is gated on
there being no error-severity finding. This is where the TUI's behaviour is proven —
the textual layer is a thin view over it.
"""

from pathlib import Path

import pytest

from ctld_tools.editmodel import EditModel
from ctld_tools.genuser import UserConfigError
from ctld_tools.reference import Reference

# A tiny DCS type set keeps unit-name checks reproducible (as in test_validate).
TYPES = frozenset({"Ural-375", "M-1 Abrams"})


@pytest.fixture(scope="module")
def ref() -> Reference:
    return Reference.from_embedded()


def model(ref, **kw) -> EditModel:
    return EditModel(ref=ref, types=TYPES, **kw)


# --- operations mutate the state -------------------------------------------------


def test_add_crate_appends_and_validates(ref):
    m = model(ref)
    m.add_crate({"section": "Support", "name": "Ural Ammo", "unit": "Ural-375", "weight_kg": 2000})
    assert m.config["crates"]["add"] == [
        {"section": "Support", "name": "Ural Ammo", "unit": "Ural-375", "weight_kg": 2000}
    ]
    assert m.can_generate


def test_remove_crate_by_name(ref):
    m = model(ref)
    m.remove_crate("Heavy Tank - Abrams")
    assert m.config["crates"]["remove"] == ["Heavy Tank - Abrams"]
    assert m.can_generate


def test_patch_crate(ref):
    m = model(ref)
    m.patch_crate({"name": "Humvee - TOW", "cratesRequired": 3})
    assert m.config["crates"]["patch"] == [{"name": "Humvee - TOW", "cratesRequired": 3}]
    assert m.can_generate


def test_add_and_remove_troop(ref):
    m = model(ref)
    m.add_troop({"name": "Recon", "inf": 3})
    m.remove_troop("5x - Mortar Squad")
    assert m.config["troops"]["add"] == [{"name": "Recon", "inf": 3}]
    assert m.config["troops"]["remove"] == ["5x - Mortar Squad"]
    assert m.can_generate


def test_set_setting(ref):
    m = model(ref)
    m.set_setting("numberOfTroops", 8)
    assert m.config["settings"] == {"numberOfTroops": 8}
    assert m.can_generate


def test_append_array(ref):
    m = model(ref)
    m.append_array("transportPilotNames", "heli_x")
    assert m.config["arrays"]["transportPilotNames"] == ["heli_x"]
    assert m.can_generate


def test_patch_troop(ref):
    m = model(ref)
    m.patch_troop({"name": "Standard Group", "inf": 9})
    assert m.config["troops"]["patch"] == [{"name": "Standard Group", "inf": 9}]
    assert m.can_generate


# --- undo / redo -----------------------------------------------------------------


def test_undo_reverts_last_operation(ref):
    m = model(ref)
    assert not m.can_undo
    m.set_setting("numberOfTroops", 8)
    assert m.can_undo
    assert m.undo() is True
    assert "settings" not in m.config or m.config["settings"] == {}
    assert not m.can_undo


def test_redo_reapplies(ref):
    m = model(ref)
    m.remove_crate("Heavy Tank - Abrams")
    m.undo()
    assert m.can_redo
    assert m.redo() is True
    assert m.config["crates"]["remove"] == ["Heavy Tank - Abrams"]


def test_new_edit_clears_redo(ref):
    m = model(ref)
    m.set_setting("a", 1)
    m.undo()
    assert m.can_redo
    m.set_setting("b", 2)  # a fresh edit
    assert not m.can_redo


def test_undo_redo_noop_when_empty(ref):
    m = model(ref)
    assert m.undo() is False
    assert m.redo() is False


def test_dirty_flag_tracks_unsaved(ref, tmp_path):
    m = model(ref)
    assert not m.dirty
    m.set_setting("numberOfTroops", 8)
    assert m.dirty
    m.save(tmp_path / "x.yaml")
    assert not m.dirty
    m.undo()
    assert m.dirty  # reverting is itself an unsaved change


# --- delete_entry ----------------------------------------------------------------


def test_delete_crate_add_entry(ref):
    m = model(ref)
    m.add_crate({"section": "Support", "name": "A", "unit": "Ural-375", "weight_kg": 111})
    m.add_crate({"section": "Support", "name": "B", "unit": "Ural-375", "weight_kg": 222})
    m.delete_entry(("crates", "add", 0))
    assert [e["name"] for e in m.config["crates"]["add"]] == ["B"]


def test_delete_troop_add_entry_is_undoable(ref):
    m = model(ref)
    m.add_troop({"name": "Recon", "inf": 3})
    m.delete_entry(("troops", "add", 0))
    assert m.config["troops"]["add"] == []
    m.undo()  # brings the troop back
    assert m.config["troops"]["add"] == [{"name": "Recon", "inf": 3}]


def test_delete_setting_and_array(ref):
    m = model(ref)
    m.set_setting("numberOfTroops", 8)
    m.append_array("transportPilotNames", "heli_x")
    m.delete_entry(("settings", "numberOfTroops"))
    m.delete_entry(("arrays", "transportPilotNames", 0))
    assert m.config["settings"] == {}
    assert "transportPilotNames" not in m.config.get("arrays", {})


# --- live validation gates generation --------------------------------------------


def test_unknown_unit_blocks_generation(ref):
    m = model(ref)
    m.add_crate({"name": "X", "unit": "NotAUnit", "weight_kg": 9001})
    assert not m.can_generate
    assert any(f.key == "validate.crate.unknown_unit" for f in m.findings)


def test_bad_array_setting_blocks_generation(ref):
    m = model(ref)
    m.append_array("notAnArray", 1)
    assert not m.can_generate


def test_generate_refused_while_errors(ref, tmp_path):
    m = model(ref)
    m.remove_troop("No Such Group")
    assert not m.can_generate
    with pytest.raises(UserConfigError):
        m.generate(tmp_path / "out.lua")


def test_generate_writes_lua_when_clean(ref, tmp_path):
    m = model(ref)
    m.remove_crate("Heavy Tank - Abrams")
    out = tmp_path / "CTLD_userConfig.lua"
    m.generate(out)
    text = out.read_text(encoding="utf-8")
    assert "ctld.removeCrate" in text


# --- load / save round-trip ------------------------------------------------------


# --- remove_from_list / restore_list_entry (ticket 10) ---------------------------


def test_remove_from_list_adds_arrayRemovals_entry(ref):
    m = model(ref)
    m.remove_from_list("transportPilotNames", "helicargo1")
    assert m.config["arrayRemovals"]["transportPilotNames"] == ["helicargo1"]


def test_restore_list_entry_removes_arrayRemovals_entry(ref):
    m = model(ref)
    m.remove_from_list("transportPilotNames", "helicargo1")
    m.restore_list_entry("transportPilotNames", "helicargo1")
    assert "arrayRemovals" not in m.config


def test_remove_from_list_undo_clears_removal(ref):
    m = model(ref)
    m.remove_from_list("transportPilotNames", "helicargo1")
    m.undo()
    assert "arrayRemovals" not in m.config


def test_restore_list_entry_undo_brings_removal_back(ref):
    m = model(ref)
    m.remove_from_list("transportPilotNames", "helicargo1")
    m.restore_list_entry("transportPilotNames", "helicargo1")
    m.undo()
    assert m.config["arrayRemovals"]["transportPilotNames"] == ["helicargo1"]


# --- load / save round-trip ------------------------------------------------------


def test_load_then_save_round_trips_operations(ref, tmp_path):
    src_yaml = tmp_path / "user-config.yaml"
    src_yaml.write_text(
        "crates:\n  remove:\n    - Heavy Tank - Abrams\n",
        encoding="utf-8",
    )
    m = EditModel.load(src_yaml, ref=ref, types=TYPES)
    assert m.config["crates"]["remove"] == ["Heavy Tank - Abrams"]
    m.set_setting("numberOfTroops", 6)

    out_yaml = tmp_path / "saved.yaml"
    m.save(out_yaml)
    reloaded = EditModel.load(out_yaml, ref=ref, types=TYPES)
    assert reloaded.config["crates"]["remove"] == ["Heavy Tank - Abrams"]
    assert reloaded.config["settings"] == {"numberOfTroops": 6}
