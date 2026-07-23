"""GUI smoke tests: the tkinter shell starts and exposes the expected widgets.

Thin by design — proves the UI↔model wiring at the highest seam: the window builds
without error, key named widgets are present, the model loads correctly, and the
save/generate entry points reach EditModel. Tests run synchronously using _test_mode=True
(the window is hidden; mainloop is never called). On headless CI (ubuntu-latest) the
xvfb-run wrapper in the workflow provides the required display.
"""

from tkinter import ttk

import pytest

from ctld_tools.editmodel import EditModel
from ctld_tools.reference import Reference
from ctld_tools.tui.app import CtldToolsApp


@pytest.fixture(autouse=True)
def _isolated_cwd(tmp_path, monkeypatch):
    """Run each test in a clean cwd so a stray user-config.yaml can't be auto-loaded."""
    monkeypatch.chdir(tmp_path)


@pytest.fixture
def app():
    a = CtldToolsApp(_test_mode=True)
    yield a
    a.root.destroy()


# --- structural tests -----------------------------------------------------------


def test_app_starts_with_embedded_reference(app):
    assert isinstance(app.model.ref, Reference)


def test_app_has_catalogue_treeview(app):
    widget = app.root.nametowidget(".paned.tree_frame.catalogue")
    assert isinstance(widget, ttk.Treeview)


def test_app_has_footer_save_button(app):
    widget = app.root.nametowidget(".footer.btn_save")
    assert isinstance(widget, ttk.Button)


def test_app_has_footer_generate_button(app):
    widget = app.root.nametowidget(".footer.btn_generate")
    assert isinstance(widget, ttk.Button)


def test_app_has_footer_inject_button(app):
    widget = app.root.nametowidget(".footer.btn_inject")
    assert isinstance(widget, ttk.Button)


def test_app_has_status_label(app):
    widget = app.root.nametowidget(".footer.status")
    assert isinstance(widget, ttk.Label)


# --- model wiring tests ---------------------------------------------------------


def test_loads_existing_file_on_start(tmp_path):
    existing = tmp_path / "user-config.yaml"
    existing.write_text("settings:\n  numberOfTroops: 5\n", encoding="utf-8")
    a = CtldToolsApp(yaml_path=existing, _test_mode=True)
    try:
        assert a.model.config["settings"] == {"numberOfTroops": 5}
    finally:
        a.root.destroy()


def test_save_writes_yaml(tmp_path):
    out = tmp_path / "user-config.yaml"
    a = CtldToolsApp(yaml_path=out, _test_mode=True)
    try:
        a.model.set_setting("numberOfTroops", 7)
        a._save()
        assert out.exists()
        assert EditModel.load(out).config["settings"] == {"numberOfTroops": 7}
    finally:
        a.root.destroy()


def test_generate_writes_lua(tmp_path):
    a = CtldToolsApp(yaml_path=tmp_path / "user-config.yaml", _test_mode=True)
    try:
        a.model.remove_crate("Heavy Tank - Abrams")  # valid op → generation allowed
        a._generate()
        assert (tmp_path / "CTLD_userConfig.lua").exists()
    finally:
        a.root.destroy()


def test_generate_button_disabled_when_errors(tmp_path):
    a = CtldToolsApp(yaml_path=tmp_path / "user-config.yaml", _test_mode=True)
    try:
        a.model.remove_troop("No Such Group")  # unknown troop → validation error
        a._refresh_status()
        state = str(a._gen_btn.cget("state"))
        assert state == "disabled"
    finally:
        a.root.destroy()


def test_status_shows_ok_when_no_findings(app):
    from ctld_tools.i18n import t as tr

    assert app._status_var.get() == tr("tui.validation.ok")


def test_status_shows_error_count_when_errors(tmp_path):
    a = CtldToolsApp(yaml_path=tmp_path / "user-config.yaml", _test_mode=True)
    try:
        a.model.remove_troop("No Such Group")
        a._refresh_status()
        status = a._status_var.get()
        assert "1" in status  # one error
    finally:
        a.root.destroy()
