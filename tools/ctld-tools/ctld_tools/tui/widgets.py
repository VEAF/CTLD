"""Reusable tkinter widgets for the GUI.

`Tooltip` is a lightweight hover-tooltip helper: bind it to any widget and it shows a
`tk.Toplevel` label near the cursor when the mouse enters, and destroys it on leave.
All user-visible strings should still go through the i18n layer before being passed in.
"""

from __future__ import annotations

import tkinter as tk


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
