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


#: The default filter of the open dialog. One entry covering both, because the two are the same
#: task: reopening a configuration, whether it sits in a `.yaml` or inside the `.miz` it was
#: installed into. A `.miz`-only entry would need the Mission Maker to know which to pick first,
#: and a `.yaml`-only default hid the mission case entirely (reported by David: "no button").
OPEN_FILETYPES = [
    ("CTLD config or mission", "*.yaml *.yml *.miz"),
    ("Config YAML", "*.yaml *.yml"),
    ("DCS mission", "*.miz"),
    ("All files", "*.*"),
]


def open_config() -> str | None:
    return _ask("askopenfilename", filetypes=OPEN_FILETYPES)


def save_config() -> str | None:
    return _ask("asksaveasfilename", defaultextension=".yaml", filetypes=[("Config YAML", "*.yaml")])


def pick_miz() -> str | None:
    return _ask("askopenfilename", filetypes=[("DCS mission", "*.miz")])
