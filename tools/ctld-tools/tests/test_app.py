"""TUI smoke tests: the app starts on the embedded reference and drives the model.

Thin by design (per the PRD) — proves the UI↔model wiring at the highest seam: the
Add→type→form flow reaches the model, delete-from-tree with confirmation works, undo
reverts, save round-trips, and generation is gated on validation. Asserts target stable
element ids and model state, not translated labels.
"""

import pytest
from textual.widgets import Button, Input, OptionList, Select, Tree

from ctld_tools.editmodel import EditModel
from ctld_tools.reference import Reference
from ctld_tools.tui.app import CtldToolsApp
from ctld_tools.tui.forms import AddCrateForm, ConfirmModal, FileBrowserModal, _MizDirectoryTree
from ctld_tools.tui.widgets import FilterablePicker


@pytest.fixture(autouse=True)
def _isolated_cwd(tmp_path, monkeypatch):
    """Run each test in a clean cwd so a stray user-config.yaml can't be auto-loaded."""
    monkeypatch.chdir(tmp_path)


def _leaf_with(tree: Tree, address: tuple):
    for section in tree.root.children:
        for leaf in section.children:
            if leaf.data == address:
                return leaf
    return None


async def test_app_starts_with_embedded_reference_and_sections():
    app = CtldToolsApp()
    async with app.run_test():
        assert isinstance(app.model.ref, Reference)
        tree = app.query_one("#config", Tree)
        assert len(tree.root.children) == 4  # settings / crates / troops / arrays


async def test_add_crate_through_ui_reaches_model():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        await pilot.click("#add")  # action button
        await pilot.pause()
        await pilot.click("#type-crate")  # type chooser
        await pilot.pause()
        assert isinstance(app.screen, AddCrateForm)
        app.query_one("#name", Input).value = "Smoke Crate"
        app.query_one("#weight", Input).value = "123456"  # unlikely to collide
        option_list = app.query_one("#unit-picker", FilterablePicker).query_one(OptionList)
        unit = str(option_list.get_option_at_index(0).prompt)  # a real DCS type
        option_list.highlighted = 0
        option_list.action_select()
        await pilot.pause()
        await pilot.click("#submit")
        await pilot.pause()

    adds = app.model.config["crates"]["add"]
    assert any(e.get("name") == "Smoke Crate" and e.get("unit") == unit for e in adds)


async def test_edit_entry_prefills_and_updates_in_place():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        # A crate added without a name → error; we edit it to fix the name.
        app.model.add_crate({"section": "Support", "unit": "Ural-375", "weight_kg": 4242})
        app._refresh()
        await pilot.pause()
        tree = app.query_one("#config", Tree)
        tree.move_cursor(_leaf_with(tree, ("crates", "add", 0)))
        await pilot.pause()
        app.action_edit_entry()
        await pilot.pause()
        assert isinstance(app.screen, AddCrateForm)
        assert app.query_one("#name", Input).value == ""  # was missing
        assert app.query_one("#weight", Input).value == "4242"  # pre-filled from the entry
        app.query_one("#name", Input).value = "Fixed Ammo"
        await pilot.click("#submit")
        await pilot.pause()

    adds = app.model.config["crates"]["add"]
    assert len(adds) == 1  # updated in place, not appended
    assert adds[0]["name"] == "Fixed Ammo"
    assert adds[0]["weight_kg"] == 4242  # other fields preserved


async def test_delete_from_tree_with_confirmation():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.add_troop({"name": "Recon", "inf": 3})
        app._refresh()
        await pilot.pause()
        tree = app.query_one("#config", Tree)
        tree.move_cursor(_leaf_with(tree, ("troops", "add", 0)))
        await pilot.pause()
        app.action_delete_entry()
        await pilot.pause()
        await pilot.click("#yes")  # confirm
        await pilot.pause()

    assert app.model.config["troops"]["add"] == []


async def test_undo_binding_reverts():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.set_setting("numberOfTroops", 8)
        app._refresh()
        await pilot.pause()
        await pilot.press("ctrl+z")
        await pilot.pause()

    assert not app.model.config.get("settings")


async def test_set_setting_through_ui_prefills_default():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        await pilot.click("#add")
        await pilot.pause()
        await pilot.click("#type-setting")
        await pilot.pause()
        picker = app.query_one("#setting-picker", FilterablePicker)
        picker.query_one(Input).value = "numberOfTroops"  # filter down to the one setting
        await pilot.pause()
        option_list = picker.query_one(OptionList)
        option_list.highlighted = 0
        option_list.action_select()
        await pilot.pause()
        assert app.query_one("#value", Input).value == "10"  # default pre-filled
        app.query_one("#value", Input).value = "7"
        await pilot.click("#submit")
        await pilot.pause()

    assert app.model.config["settings"]["numberOfTroops"] == 7


async def test_bool_setting_offers_a_select():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        await pilot.click("#add")
        await pilot.pause()
        await pilot.click("#type-setting")
        await pilot.pause()
        picker = app.query_one("#setting-picker", FilterablePicker)
        picker.query_one(Input).value = "debug"  # a boolean setting (default False)
        await pilot.pause()
        option_list = picker.query_one(OptionList)
        option_list.highlighted = 0
        option_list.action_select()
        await pilot.pause()
        select = app.query_one("#value-select", Select)  # bool → Select, not free text
        select.value = "true"
        await pilot.pause()
        await pilot.click("#submit")
        await pilot.pause()

    assert app.model.config["settings"]["debug"] is True


async def test_quit_confirms_when_dirty():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.set_setting("numberOfTroops", 8)  # makes the model dirty
        app._refresh()
        await pilot.pause()
        await app.action_quit()
        await pilot.pause()
        assert isinstance(app.screen, ConfirmModal)  # not exited — asks first
        await pilot.click("#no")
        await pilot.pause()
        assert app.is_running


def test_miz_tree_filters_to_miz_and_dirs(tmp_path):
    (tmp_path / "mission.miz").write_text("x")
    (tmp_path / "notes.txt").write_text("x")
    (tmp_path / "sub").mkdir()
    tree = _MizDirectoryTree(str(tmp_path))
    kept = set(tree.filter_paths([tmp_path / "mission.miz", tmp_path / "notes.txt", tmp_path / "sub"]))
    assert (tmp_path / "mission.miz") in kept
    assert (tmp_path / "notes.txt") not in kept  # non-.miz hidden
    assert (tmp_path / "sub") in kept  # dirs kept for navigation


async def test_inject_opens_file_browser(tmp_path):
    app = CtldToolsApp(yaml_path=tmp_path / "user-config.yaml")
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.remove_crate("Heavy Tank - Abrams")  # valid op → generation allowed
        app._refresh()
        await pilot.click("#inject")
        await pilot.pause()
        assert isinstance(app.screen, FileBrowserModal)


async def test_settings_picker_searchable_by_description():
    from ctld_tools.i18n import language

    with language("en"):
        app = CtldToolsApp()
        async with app.run_test(size=(120, 40)) as pilot:
            await pilot.click("#add")
            await pilot.pause()
            await pilot.click("#type-setting")
            await pilot.pause()
            picker = app.query_one("#setting-picker", FilterablePicker)
            picker.query_one(Input).value = "interface"  # a word from i18n_lang's description, not its name
            await pilot.pause()
            option_list = picker.query_one(OptionList)
            ids = [option_list.get_option_at_index(i).id for i in range(option_list.option_count)]
            assert "i18n_lang" in ids  # matched via its description


async def test_generate_disabled_while_errors():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.remove_troop("No Such Group")  # unknown troop → error
        app._refresh()
        await pilot.pause()
        assert app.query_one("#generate", Button).disabled


async def test_save_through_ui_round_trips(tmp_path):
    out = tmp_path / "user-config.yaml"
    app = CtldToolsApp(yaml_path=out)  # fixed target, no prompt
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.set_setting("numberOfTroops", 7)
        app._refresh()
        await pilot.click("#save")
        await pilot.pause()

    assert out.exists()
    assert EditModel.load(out).config["settings"] == {"numberOfTroops": 7}


async def test_loads_existing_file_on_start(tmp_path):
    existing = tmp_path / "user-config.yaml"
    existing.write_text("settings:\n  numberOfTroops: 5\n", encoding="utf-8")
    app = CtldToolsApp(yaml_path=existing)
    async with app.run_test():
        assert app.model.config["settings"] == {"numberOfTroops": 5}


async def test_generate_writes_canonical_file(tmp_path):
    app = CtldToolsApp(yaml_path=tmp_path / "user-config.yaml")
    async with app.run_test(size=(120, 40)) as pilot:
        app.model.remove_crate("Heavy Tank - Abrams")  # a valid op
        app._refresh()
        await pilot.click("#generate")
        await pilot.pause()

    assert (tmp_path / "CTLD_userConfig.lua").exists()
