"""Form tests: coerce() scalar parser + ScalarForm widget behaviour."""

from __future__ import annotations

import tkinter as tk

import pytest

from ctld_tools.tui.app import CtldToolsApp
from ctld_tools.tui.forms import ScalarForm, coerce

# --- coerce() -------------------------------------------------------------------


def test_coerce_empty_returns_none():
    assert coerce("") is None
    assert coerce("   ") is None


def test_coerce_true():
    assert coerce("true") is True


def test_coerce_false():
    assert coerce("false") is False


def test_coerce_true_case_insensitive():
    assert coerce("True") is True
    assert coerce("TRUE") is True


def test_coerce_int():
    assert coerce("42") == 42
    assert isinstance(coerce("42"), int)


def test_coerce_float():
    assert coerce("3.14") == pytest.approx(3.14)
    assert isinstance(coerce("3.14"), float)


def test_coerce_string():
    assert coerce("hello") == "hello"


def test_coerce_strips_whitespace():
    assert coerce("  7  ") == 7


# --- ScalarForm -----------------------------------------------------------------


@pytest.fixture(autouse=True)
def _isolated_cwd(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)


@pytest.fixture
def app():
    a = CtldToolsApp(_test_mode=True)
    yield a
    a.root.destroy()


def test_apply_commits_scalar_to_model(app):
    app._open_scalar_form("numberOfTroops")
    form = app._current_form
    form._value_var.set("7")
    form._apply()
    assert app.model.config["settings"]["numberOfTroops"] == 7


def test_cancel_does_not_modify_model(app):
    app._open_scalar_form("numberOfTroops")
    form = app._current_form
    form._value_var.set("7")
    form._cancel()
    assert "numberOfTroops" not in app.model.config.get("settings", {})


def test_no_delete_button_for_scalar(app):
    app._open_scalar_form("numberOfTroops")
    form = app._current_form
    all_btn_texts: list[str] = []

    def collect_buttons(widget):
        for child in widget.winfo_children():
            if isinstance(child, tk.ttk.Button):
                all_btn_texts.append(str(child.cget("text")))
            collect_buttons(child)

    collect_buttons(form)
    assert not any("delete" in txt.lower() or "supprimer" in txt.lower() for txt in all_btn_texts)


def test_bool_scalar_uses_combobox(app):
    # "debug" is a bool setting in the reference
    app._open_scalar_form("debug")
    form = app._current_form
    assert isinstance(form._widget, tk.ttk.Combobox)


def test_free_text_scalar_uses_entry(app):
    # "numberOfTroops" is an int — should use Entry
    app._open_scalar_form("numberOfTroops")
    form = app._current_form
    assert isinstance(form._widget, tk.ttk.Entry)


def test_enum_scalar_uses_combobox(app):
    # "JTAC_lock" has choices in the schema
    app._open_scalar_form("JTAC_lock")
    form = app._current_form
    assert isinstance(form._widget, tk.ttk.Combobox)


def test_form_prefills_current_value(app):
    app.model.set_setting("numberOfTroops", 7)
    app._open_scalar_form("numberOfTroops")
    form = app._current_form
    assert form._value_var.get() == "7"


def test_form_prefills_default_when_unset(app):
    # numberOfTroops default is 10 per the reference
    app._open_scalar_form("numberOfTroops")
    form = app._current_form
    assert form._value_var.get() == "10"
