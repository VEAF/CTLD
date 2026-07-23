"""TUI smoke tests: the app starts on the embedded reference and drives the model.

Thin by design (per the PRD) — proves the UI↔model wiring at the highest seam: the
Add→type→form flow reaches the model, delete-from-tree with confirmation works, undo
reverts, save round-trips, and generation is gated on validation. Asserts target stable
element ids and model state, not translated labels.
"""

import pytest
from textual.widgets import Button, Input, Label, OptionList, Select, Tree

from ctld_tools.editmodel import EditModel
from ctld_tools.reference import Reference
from ctld_tools.tui.app import CtldToolsApp
from ctld_tools.tui.forms import AddCrateForm, AddTroopForm, ConfirmModal, FileBrowserModal, _MizDirectoryTree
from ctld_tools.tui.widgets import FilterablePicker


def _pick(picker: FilterablePicker, value: str) -> None:
    """Select the option whose id == value in a FilterablePicker's OptionList."""
    option_list = picker.query_one(OptionList)
    idx = next(i for i in range(option_list.option_count) if option_list.get_option_at_index(i).id == value)
    option_list.highlighted = idx
    option_list.action_select()


@pytest.fixture(autouse=True)
def _isolated_cwd(tmp_path, monkeypatch):
    """Run each test in a clean cwd so a stray user-config.yaml can't be auto-loaded."""
    monkeypatch.chdir(tmp_path)


def _leaf_with(tree: Tree, address: tuple):
    stack = list(tree.root.children)
    while stack:
        node = stack.pop()
        if node.data == address:
            return node
        stack.extend(node.children)
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


async def test_patch_troop_via_ui_writes_only_changed_fields():
    """Modify → pick target → full pre-filled form → only the changed field is written."""
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        await pilot.click("#patch")
        await pilot.pause()
        await pilot.click("#type-troop")
        await pilot.pause()
        _pick(app.query_one("#picker", FilterablePicker), "2x - Anti Air")
        await pilot.pause()
        assert isinstance(app.screen, AddTroopForm)
        assert app.query_one("#name", Input).value == "2x - Anti Air"
        assert app.query_one("#aa", Input).value == "6"  # pre-filled from the default
        assert app.query_one("#inf", Input).value == "4"
        app.query_one("#aa", Input).value = "8"  # the only change
        await pilot.click("#submit")
        await pilot.pause()

    assert app.model.config["troops"]["patch"] == [{"name": "2x - Anti Air", "aa": 8}]


async def test_patch_form_shows_ctld_default_hint():
    from ctld_tools.i18n import language

    with language("en"):
        app = CtldToolsApp()
        async with app.run_test(size=(120, 50)) as pilot:
            await pilot.click("#patch")
            await pilot.pause()
            await pilot.click("#type-troop")
            await pilot.pause()
            _pick(app.query_one("#picker", FilterablePicker), "Anti Air")  # default aa 3
            await pilot.pause()
            labels = [str(w.renderable) for w in app.query(Label)]
            assert any("CTLD default:" in text and "3" in text for text in labels)


async def test_edit_patch_line_reverting_to_default_drops_it():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        app.model.patch_troop({"name": "2x - Anti Air", "aa": 8})
        app._refresh()
        await pilot.pause()
        tree = app.query_one("#config", Tree)
        tree.move_cursor(_leaf_with(tree, ("troops", "patch", 0)))
        await pilot.pause()
        app.action_edit_entry()
        await pilot.pause()
        assert isinstance(app.screen, AddTroopForm)
        assert app.query_one("#aa", Input).value == "8"  # current = default ⊕ patch
        app.query_one("#aa", Input).value = "6"  # back to the CTLD default
        await pilot.click("#submit")
        await pilot.pause()

    assert app.model.config["troops"]["patch"] == []  # nothing differs → line dropped


async def test_tree_groups_entries_by_op_nature():
    """Crate/troop leaves live under a word-headed sub-group, not directly on the section."""
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        app.model.add_troop({"name": "Recon", "inf": 3})
        app._refresh()
        await pilot.pause()
        leaf = _leaf_with(app.query_one("#config", Tree), ("troops", "add", 0))
        assert leaf is not None
        group = leaf.parent  # the "Added" sub-group
        assert group.data is None and len(group.children) == 1
        assert group.parent.data is None  # the Troop section


async def test_selection_buttons_enable_only_on_a_leaf():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        edit = app.query_one("#edit", Button)
        delete = app.query_one("#delete-btn", Button)
        assert edit.disabled and delete.disabled  # nothing selected at start
        app.model.add_troop({"name": "Recon", "inf": 3})
        app._refresh()
        await pilot.pause()
        tree = app.query_one("#config", Tree)
        tree.move_cursor(_leaf_with(tree, ("troops", "add", 0)))
        await pilot.pause()
        assert not edit.disabled and not delete.disabled  # a leaf is selected


async def test_edit_button_opens_editor_for_selected_line():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        app.model.add_troop({"name": "Recon", "inf": 3})
        app._refresh()
        await pilot.pause()
        tree = app.query_one("#config", Tree)
        tree.move_cursor(_leaf_with(tree, ("troops", "add", 0)))
        await pilot.pause()
        await pilot.click("#edit")
        await pilot.pause()
        assert isinstance(app.screen, AddTroopForm)


async def test_remove_op_auto_selects_new_line():
    """After a catalogue op, the cursor lands on the line it created."""
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        await pilot.click("#remove")
        await pilot.pause()
        await pilot.click("#type-troop")
        await pilot.pause()
        target = app.model.ref.troop_names()[0]
        _pick(app.query_one("#picker", FilterablePicker), target)
        await pilot.pause()
        cursor = app.query_one("#config", Tree).cursor_node
        assert cursor is not None and cursor.data == ("troops", "remove", 0)


async def test_patch_op_auto_selects_new_line():
    app = CtldToolsApp()
    async with app.run_test(size=(120, 50)) as pilot:
        await pilot.click("#patch")
        await pilot.pause()
        await pilot.click("#type-troop")
        await pilot.pause()
        _pick(app.query_one("#picker", FilterablePicker), "2x - Anti Air")
        await pilot.pause()
        app.query_one("#aa", Input).value = "8"
        await pilot.click("#submit")
        await pilot.pause()
        cursor = app.query_one("#config", Tree).cursor_node
        assert cursor is not None and cursor.data == ("troops", "patch", 0)


async def test_remove_picker_greys_already_consumed_names():
    """A troop already in the remove diff is non-selectable in the remove picker."""
    app = CtldToolsApp()
    async with app.run_test(size=(120, 40)) as pilot:
        target = app.model.ref.troop_names()[0]
        app.model.remove_troop(target)
        app._refresh()
        await pilot.pause()
        await pilot.click("#remove")
        await pilot.pause()
        await pilot.click("#type-troop")
        await pilot.pause()
        option_list = app.query_one("#picker", FilterablePicker).query_one(OptionList)
        by_id = {
            option_list.get_option_at_index(i).id: option_list.get_option_at_index(i)
            for i in range(option_list.option_count)
        }
        assert by_id[target].disabled is True


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
