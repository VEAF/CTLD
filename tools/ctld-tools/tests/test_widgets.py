"""Tests for the Tooltip helper widget."""

import tkinter as tk

import pytest

from ctld_tools.tui.widgets import Tooltip


@pytest.fixture
def root():
    r = tk.Tk()
    r.withdraw()
    yield r
    r.destroy()


def test_tooltip_show_creates_toplevel(root):
    label = tk.Label(root, text="Field")
    tip = Tooltip(label, "A description.")
    tip._show()
    assert tip._tip is not None
    assert isinstance(tip._tip, tk.Toplevel)


def test_tooltip_hide_destroys_toplevel(root):
    label = tk.Label(root, text="Field")
    tip = Tooltip(label, "A description.")
    tip._show()
    tip._hide()
    assert tip._tip is None


def test_tooltip_show_noop_when_already_visible(root):
    label = tk.Label(root, text="Field")
    tip = Tooltip(label, "A description.")
    tip._show()
    first = tip._tip
    tip._show()  # second call — must not replace the existing toplevel
    assert tip._tip is first


def test_tooltip_empty_text_does_not_show(root):
    label = tk.Label(root, text="Field")
    tip = Tooltip(label, "")
    tip._show()
    assert tip._tip is None


def test_tooltip_hide_noop_when_not_visible(root):
    label = tk.Label(root, text="Field")
    tip = Tooltip(label, "A description.")
    tip._hide()  # no Toplevel created yet — must not raise
    assert tip._tip is None
