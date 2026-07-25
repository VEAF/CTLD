"""Native OS file dialogs, driven by the local backend (which runs as the MM).

The browser cannot pick arbitrary filesystem paths, so open/save/pick-miz go through a
native tkinter dialog on the machine hosting the backend. Interactive-only: never invoked
in CI (the endpoints are used by the desktop exe). Each call is a thin wrapper so tests can
monkeypatch it.
"""

from __future__ import annotations


def _ask(kind: str, **kw: object) -> str | None:
    import tkinter
    from tkinter import filedialog

    root = tkinter.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    try:
        path = getattr(filedialog, kind)(**kw)
    finally:
        root.destroy()
    return path or None


def open_config() -> str | None:
    return _ask("askopenfilename", filetypes=[("Config YAML", "*.yaml *.yml"), ("All files", "*.*")])


def save_config() -> str | None:
    return _ask("asksaveasfilename", defaultextension=".yaml", filetypes=[("Config YAML", "*.yaml")])


def pick_miz() -> str | None:
    return _ask("askopenfilename", filetypes=[("DCS mission", "*.miz")])
