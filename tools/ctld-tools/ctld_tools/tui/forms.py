"""Form helpers for the GUI — value coercion and editor form widgets.

The Textual modal forms have been removed in v2 (UX-CTLD-TOOLS-V2). This module now
contains the pure-Python coercion helper shared across editor forms, and the ScalarForm
widget used to edit individual scalar settings.
"""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk

from ctld_tools.i18n import t


def coerce(text: str):
    """Best-effort scalar from a form input: bool, int, float, str, or None if blank."""
    stripped = text.strip()
    if not stripped:
        return None
    low = stripped.lower()
    if low in ("true", "false"):
        return low == "true"
    try:
        return int(stripped)
    except ValueError:
        pass
    try:
        return float(stripped)
    except ValueError:
        return stripped


class ScalarForm(ttk.Frame):
    """Editor panel for one scalar setting (Type A — no add/delete)."""

    def __init__(self, parent, *, key, default, current, choices, description, on_apply, on_cancel):
        super().__init__(parent, padding=12)
        self._key = key
        self._on_apply = on_apply
        self._on_cancel = on_cancel

        # Setting name as title
        ttk.Label(self, text=key, font=("", 11, "bold")).pack(anchor="w")

        # Field label + tooltip
        default_str = str(default) if default is not None else ""
        field_label = ttk.Label(self, text=t("tui.label.setting_default", name=key, default=default_str))
        field_label.pack(anchor="w", pady=(10, 2))
        if description:
            from ctld_tools.tui.widgets import Tooltip

            Tooltip(field_label, description)

        # Value widget: Combobox for bool/enum, Entry for free text
        self._value_var = tk.StringVar()
        is_bool = isinstance(default, bool)
        widget: ttk.Combobox | ttk.Entry
        if is_bool:
            current_str = str(current).lower() if isinstance(current, bool) else str(current)
            self._value_var.set(current_str)
            widget = ttk.Combobox(
                self,
                textvariable=self._value_var,
                values=["true", "false"],
                state="readonly",
                width=30,
            )
        elif choices:
            self._value_var.set(str(current) if current is not None else "")
            widget = ttk.Combobox(
                self,
                textvariable=self._value_var,
                values=choices,
                state="readonly",
                width=30,
            )
        else:
            self._value_var.set(str(current) if current is not None else "")
            widget = ttk.Entry(self, textvariable=self._value_var, width=30)
        self._widget: ttk.Combobox | ttk.Entry = widget
        self._widget.pack(anchor="w", pady=4)

        # Inline validation / error label
        self._error_var = tk.StringVar()
        self._error_label = ttk.Label(self, textvariable=self._error_var, foreground="red")
        self._error_label.pack(anchor="w")

        # Buttons: Apply / Cancel — NO Delete (Type A)
        btn_frame = ttk.Frame(self)
        btn_frame.pack(anchor="w", pady=(10, 0))
        ttk.Button(btn_frame, text=t("tui.btn.apply"), command=self._apply).pack(side="left", padx=(0, 4))
        ttk.Button(btn_frame, text=t("tui.btn.cancel"), command=self._cancel).pack(side="left")

    def set_error(self, msg: str) -> None:
        self._error_var.set(msg)

    def _apply(self) -> None:
        self._error_var.set("")
        value = coerce(self._value_var.get())
        self._on_apply(self._key, value)

    def _cancel(self) -> None:
        self._on_cancel()
