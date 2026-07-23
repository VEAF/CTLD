"""Catalogue tree visual state tests.

Asserts that tree items carry the correct tag (default / modified) and label
given a known EditModel.config. Tests are synchronous (no mainloop).
"""

import pytest

from ctld_tools.tui.app import CtldToolsApp


@pytest.fixture(autouse=True)
def _isolated_cwd(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)


@pytest.fixture
def app():
    a = CtldToolsApp(_test_mode=True)
    yield a
    a.root.destroy()


def test_parameters_section_exists(app):
    assert app._tree.exists("params")


def test_standard_subsection_exists(app):
    assert app._tree.exists("params_standard")


def test_advanced_subsection_exists(app):
    assert app._tree.exists("params_advanced")


def test_unmodified_scalar_has_default_tag(app):
    assert "default" in app._tree.item("scalar:numberOfTroops", "tags")


def test_modified_scalar_has_modified_tag(app):
    app.model.set_setting("numberOfTroops", 7)
    app._rebuild_tree()
    assert "modified" in app._tree.item("scalar:numberOfTroops", "tags")


def test_modified_scalar_label_has_asterisk(app):
    app.model.set_setting("numberOfTroops", 7)
    app._rebuild_tree()
    label = app._tree.item("scalar:numberOfTroops", "text")
    assert "*" in label


def test_standard_scalars_have_descriptions(app):
    # Every item under params_standard has a description in the schema (is_mm_facing)
    ref = app.model.ref
    std_children = app._tree.get_children("params_standard")
    assert len(std_children) > 0
    for iid in std_children:
        key = iid.removeprefix("scalar:")
        assert ref.is_mm_facing(key), f"{key} in Standard but not mm_facing"


def test_undo_restores_default_tag(app):
    app.model.set_setting("numberOfTroops", 7)
    app._rebuild_tree()
    assert "modified" in app._tree.item("scalar:numberOfTroops", "tags")
    app.model.undo()
    app._rebuild_tree()
    assert "default" in app._tree.item("scalar:numberOfTroops", "tags")


# --- Crates ---


def test_crates_section_exists(app):
    assert app._tree.exists("crates")


def test_crate_families_exist(app):
    families = [app._tree.item(iid, "text") for iid in app._tree.get_children("crates")]
    assert "Artillery" in families
    assert "Combat Vehicles" in families


def test_default_crate_has_default_tag(app):
    # Find any crate iid from Artillery family
    fam_iid = "crate_family:Artillery"
    children = app._tree.get_children(fam_iid)
    assert children, "Artillery has no children"
    assert "default" in app._tree.item(children[0], "tags")


def test_deleted_crate_has_deleted_tag(app):
    app.model.remove_crate("MLRS")
    app._rebuild_tree()
    # Find the crate iid for MLRS (weight 1002.01)
    crate_iid = "crate:Artillery:1002.01"
    assert "deleted" in app._tree.item(crate_iid, "tags")


def test_added_crate_has_added_tag(app):
    app.model.add_crate({"name": "Test Crate", "unit": "Ural-375", "weight_kg": 9999, "section": "Support"})
    app._rebuild_tree()
    # Added crate should appear with "added" tag
    add_iid = "crate_add:0"
    assert app._tree.exists(add_iid)
    assert "added" in app._tree.item(add_iid, "tags")


def test_modified_crate_has_modified_tag(app):
    app.model.patch_crate({"name": "MLRS", "cratesRequired": 5})
    app._rebuild_tree()
    crate_iid = "crate:Artillery:1002.01"
    assert "modified" in app._tree.item(crate_iid, "tags")


def test_modified_crate_label_has_asterisk(app):
    app.model.patch_crate({"name": "MLRS", "cratesRequired": 5})
    app._rebuild_tree()
    label = app._tree.item("crate:Artillery:1002.01", "text")
    assert "*" in label


def test_restored_crate_returns_to_default(app):
    app.model.remove_crate("MLRS")
    app._rebuild_tree()
    assert "deleted" in app._tree.item("crate:Artillery:1002.01", "tags")
    # Restore
    removes = app.model.config["crates"]["remove"]
    idx = removes.index("MLRS")
    app.model.delete_entry(("crates", "remove", idx))
    app._rebuild_tree()
    assert "default" in app._tree.item("crate:Artillery:1002.01", "tags")
