"""Reusable tkinter widgets for the GUI.

`Tooltip` is a lightweight hover-tooltip helper: bind it to any widget and it shows a
`tk.Toplevel` label near the cursor when the mouse enters, and destroys it on leave.
All user-visible strings should still go through the i18n layer before being passed in.
"""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk


class FilterablePicker(ttk.Frame):
    """Text entry + live-filtered listbox for picking from a large option set (DCS types)."""

    def __init__(self, parent, options: list[str], *, height: int = 6, **kwargs) -> None:
        super().__init__(parent, **kwargs)
        self._all_options = list(options)
        self._var = tk.StringVar()
        self._entry = ttk.Entry(self, textvariable=self._var)
        self._entry.pack(fill=tk.X)
        self._entry.bind("<KeyRelease>", self._on_key)
        lb_frame = ttk.Frame(self)
        lb_frame.pack(fill=tk.BOTH, expand=True)
        self._listbox = tk.Listbox(lb_frame, height=height, exportselection=False)
        scroll = ttk.Scrollbar(lb_frame, orient=tk.VERTICAL, command=self._listbox.yview)
        self._listbox.configure(yscrollcommand=scroll.set)
        self._listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self._listbox.bind("<<ListboxSelect>>", self._on_select)
        self._populate(self._all_options)

    def _on_key(self, event=None) -> None:  # noqa: ARG002
        from ctld_tools.tui.filter import matches

        query = self._var.get()
        self._populate([o for o in self._all_options if matches(o, query)])

    def _populate(self, options: list[str]) -> None:
        self._listbox.delete(0, tk.END)
        for opt in options:
            self._listbox.insert(tk.END, opt)

    def _on_select(self, event=None) -> None:  # noqa: ARG002
        sel = self._listbox.curselection()
        if sel:
            self._var.set(self._listbox.get(sel[0]))

    def get(self) -> str:
        return self._var.get()

    def set(self, value: str) -> None:
        self._var.set(value)
        from ctld_tools.tui.filter import matches

        filtered = [o for o in self._all_options if matches(o, value)] if value else self._all_options
        self._populate(filtered)
        for i, opt in enumerate(filtered):
            if opt == value:
                self._listbox.selection_set(i)
                self._listbox.see(i)
                break


class Tooltip:
    """Show a floating label near a widget when the cursor enters it.

    Usage::

        label = ttk.Label(parent, text="Field name")
        Tooltip(label, "Description shown on hover.")
    """

    def __init__(self, widget: tk.Widget, text: str) -> None:
        self._widget = widget
        self._text = text
        self._tip: tk.Toplevel | None = None
        widget.bind("<Enter>", self._show)
        widget.bind("<Leave>", self._hide)

    def _show(self, event=None) -> None:  # noqa: ARG002
        if self._tip or not self._text:
            return
        x = self._widget.winfo_rootx() + 20
        y = self._widget.winfo_rooty() + self._widget.winfo_height() + 4
        self._tip = tk.Toplevel(self._widget)
        self._tip.wm_overrideredirect(True)
        self._tip.wm_geometry(f"+{x}+{y}")
        label = tk.Label(
            self._tip,
            text=self._text,
            background="#ffffc0",
            relief=tk.SOLID,
            borderwidth=1,
            wraplength=300,
            justify=tk.LEFT,
            padx=4,
            pady=2,
        )
        label.pack()

    def _hide(self, event=None) -> None:  # noqa: ARG002
        if self._tip:
            self._tip.destroy()
            self._tip = None
