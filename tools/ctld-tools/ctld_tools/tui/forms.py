"""Form helpers for the GUI — value coercion and editor form widgets.

The Textual modal forms have been removed in v2 (UX-CTLD-TOOLS-V2). This module now
contains the pure-Python coercion helper shared across editor forms, and the ScalarForm
widget used to edit individual scalar settings.
"""

from __future__ import annotations

import tkinter as tk
from collections.abc import Callable
from tkinter import ttk

from ctld_tools.i18n import t

_SPECIFIC_PARAMS_KEYS = ("alti", "orbitRadiusNoLase", "orbitRadiusOnLase", "speed")


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


class CrateForm(ttk.Frame):
    """Editor panel for one crate entry (supports add / modify / delete / restore)."""

    def __init__(
        self,
        parent,
        *,
        family: str,
        entry: dict,
        state: str,
        on_apply: Callable,
        on_delete: Callable,
        on_restore: Callable,
        on_cancel: Callable,
    ) -> None:
        super().__init__(parent, padding=12)
        self._family = family
        self._state = state
        self._original_desc = entry.get("desc") or entry.get("name", "")
        self._on_apply = on_apply
        self._on_delete = on_delete
        self._on_restore = on_restore
        self._on_cancel = on_cancel

        # Scrollable interior
        canvas = tk.Canvas(self, borderwidth=0, highlightthickness=0)
        vscroll = ttk.Scrollbar(self, orient=tk.VERTICAL, command=canvas.yview)
        canvas.configure(yscrollcommand=vscroll.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        vscroll.pack(side=tk.RIGHT, fill=tk.Y)
        interior = ttk.Frame(canvas)
        canvas.create_window((0, 0), window=interior, anchor="nw")
        interior.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

        # Title
        title = entry.get("desc") or entry.get("name") or t("tui.crate.new")
        ttk.Label(interior, text=f"{family} / {title}", font=("", 11, "bold")).pack(anchor="w", pady=(0, 8))

        # desc field
        self._desc_var = tk.StringVar(value=self._original_desc)
        self._add_field(interior, "desc", self._desc_var)

        # unit (DCS type picker)
        ttk.Label(interior, text="unit").pack(anchor="w")
        from ctld_tools.datamine import known_dcs_types
        from ctld_tools.tui.widgets import FilterablePicker

        self._unit_picker = FilterablePicker(interior, sorted(known_dcs_types()), height=5)
        self._unit_picker.pack(fill=tk.X, pady=(0, 6))
        if entry.get("unit"):
            self._unit_picker.set(entry["unit"])

        # weight_kg (stored as "weight" in reference, "weight_kg" in editmodel)
        weight_val = entry.get("weight_kg") or entry.get("weight", "")
        self._weight_var = tk.StringVar(value=str(weight_val) if weight_val != "" else "")
        self._add_field(interior, "weight_kg", self._weight_var)

        # cratesRequired
        cr_val = entry.get("cratesRequired")
        self._crates_req_var = tk.StringVar(value=str(cr_val) if cr_val is not None else "")
        self._add_field(interior, "cratesRequired", self._crates_req_var)

        # side
        side_val = entry.get("side")
        self._side_var = tk.StringVar(value=str(side_val) if side_val is not None else "")
        side_frame = ttk.Frame(interior)
        side_frame.pack(anchor="w", fill=tk.X, pady=(0, 6))
        ttk.Label(side_frame, text="side").pack(side=tk.LEFT)
        ttk.Combobox(side_frame, textvariable=self._side_var, values=["1", "2", ""], width=8).pack(side=tk.LEFT, padx=4)

        # isJTAC (bool)
        jtac_val = entry.get("isJTAC")
        self._jtac_var = tk.StringVar(value=str(jtac_val).lower() if jtac_val is not None else "")
        jtac_frame = ttk.Frame(interior)
        jtac_frame.pack(anchor="w", fill=tk.X, pady=(0, 6))
        ttk.Label(jtac_frame, text="isJTAC").pack(side=tk.LEFT)
        ttk.Combobox(
            jtac_frame, textvariable=self._jtac_var, values=["true", "false", ""], state="readonly", width=8
        ).pack(side=tk.LEFT, padx=4)

        # spawnAs
        self._spawn_var = tk.StringVar(value=entry.get("spawnAs", ""))
        self._add_field(interior, "spawnAs", self._spawn_var)

        # specificParams (inline group — shown when family is Drone or entry has them)
        has_specific = bool(entry.get("specificParams")) or family == "Drone"
        self._specific_vars: dict[str, tk.StringVar] = {}
        if has_specific:
            ttk.Separator(interior, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=6)
            ttk.Label(interior, text="specificParams", font=("", 9, "bold")).pack(anchor="w")
            sp = entry.get("specificParams") or {}
            for sp_key in _SPECIFIC_PARAMS_KEYS:
                sp_val = sp.get(sp_key)
                var = tk.StringVar(value=str(sp_val) if sp_val is not None else "")
                self._add_field(interior, f"  {sp_key}", var)
                self._specific_vars[sp_key] = var

        # Inline error label
        self._error_var = tk.StringVar()
        ttk.Label(interior, textvariable=self._error_var, foreground="red", wraplength=350).pack(
            anchor="w", pady=(4, 0)
        )

        # Buttons
        btn_frame = ttk.Frame(interior)
        btn_frame.pack(anchor="w", pady=(10, 0))
        ttk.Button(btn_frame, text=t("tui.btn.apply"), command=self._apply).pack(side=tk.LEFT, padx=(0, 4))
        if state == "deleted":
            ttk.Button(btn_frame, text=t("tui.btn.restore"), command=self._restore).pack(side=tk.LEFT, padx=(0, 4))
        else:
            self._delete_btn = ttk.Button(btn_frame, text=t("tui.btn.delete"), command=self._delete)
            self._delete_btn.pack(side=tk.LEFT, padx=(0, 4))
        ttk.Button(btn_frame, text=t("tui.btn.cancel"), command=self._on_cancel).pack(side=tk.LEFT)

    def _add_field(self, parent, label: str, var: tk.StringVar) -> None:
        row = ttk.Frame(parent)
        row.pack(anchor="w", fill=tk.X, pady=(0, 4))
        ttk.Label(row, text=label, width=16).pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=var, width=28).pack(side=tk.LEFT)

    def set_error(self, msg: str) -> None:
        self._error_var.set(msg)

    def _collect(self) -> dict:
        """Collect current form values into an entry dict."""
        entry: dict = {}
        desc = self._desc_var.get().strip()
        if desc:
            entry["name"] = desc
            entry["desc"] = desc
        unit = self._unit_picker.get().strip()
        if unit:
            entry["unit"] = unit
        weight = coerce(self._weight_var.get())
        if weight is not None:
            entry["weight_kg"] = weight
        cr = coerce(self._crates_req_var.get())
        if cr is not None:
            entry["cratesRequired"] = cr
        side = coerce(self._side_var.get())
        if side is not None:
            entry["side"] = side
        jtac_raw = self._jtac_var.get().strip().lower()
        if jtac_raw in ("true", "false"):
            entry["isJTAC"] = jtac_raw == "true"
        spawn = self._spawn_var.get().strip()
        if spawn:
            entry["spawnAs"] = spawn
        if self._specific_vars:
            sp: dict = {}
            for k, var in self._specific_vars.items():
                v = coerce(var.get())
                if v is not None:
                    sp[k] = v
            if sp:
                entry["specificParams"] = sp
        entry["section"] = self._family
        return entry

    def _apply(self) -> None:
        self._error_var.set("")
        entry = self._collect()
        self._on_apply(self._family, entry, self._original_desc)

    def _delete(self) -> None:
        self._on_delete(self._original_desc, None)

    def _restore(self) -> None:
        self._on_restore(self._original_desc)


_AIRCRAFT_BOOL_FIELDS = (
    "cratesEnabled", "troopsEnabled", "canSlingload", "canParachuteDrop",
    "useNativeDcsCargoSystem", "canTransportWholeVehicle", "convertNativeLoadToCTLD",
)
_AIRCRAFT_NUM_FIELDS = (
    "maxCratesOnboard", "maxTroopsOnboard", "maxWholeVehiclesOnboard", "maxVehicleWeight",
)
_AIRCRAFT_LIST_FIELDS = ("loadableVehiclesBLUE", "loadableVehiclesRED")


class AircraftForm(ttk.Frame):
    """Editor panel for one capabilitiesByType entry."""

    def __init__(
        self,
        parent,
        *,
        type_name: str,
        entry: dict,
        state: str,
        on_apply: Callable,
        on_delete: Callable,
        on_restore: Callable,
        on_cancel: Callable,
        is_new: bool = False,
    ) -> None:
        super().__init__(parent, padding=12)
        self._type_name = type_name
        self._state = state
        self._on_apply = on_apply
        self._on_delete = on_delete
        self._on_restore = on_restore
        self._on_cancel = on_cancel
        self._is_new = is_new

        # Scrollable interior
        canvas = tk.Canvas(self, borderwidth=0, highlightthickness=0)
        vscroll = ttk.Scrollbar(self, orient=tk.VERTICAL, command=canvas.yview)
        canvas.configure(yscrollcommand=vscroll.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        vscroll.pack(side=tk.RIGHT, fill=tk.Y)
        interior = ttk.Frame(canvas)
        canvas.create_window((0, 0), window=interior, anchor="nw")
        interior.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

        # Title: type name (or DCS picker for new)
        if is_new:
            ttk.Label(interior, text=t("tui.aircraft.new"), font=("", 11, "bold")).pack(anchor="w", pady=(0, 4))
            ttk.Label(interior, text="type").pack(anchor="w")
            from ctld_tools.datamine import known_dcs_types
            from ctld_tools.tui.widgets import FilterablePicker
            self._type_picker = FilterablePicker(interior, sorted(known_dcs_types()), height=4)
            self._type_picker.pack(fill=tk.X, pady=(0, 8))
            if type_name:
                self._type_picker.set(type_name)
        else:
            ttk.Label(interior, text=type_name, font=("", 11, "bold")).pack(anchor="w", pady=(0, 8))
            self._type_picker = None  # type: ignore[assignment]

        # Bool fields
        self._bool_vars: dict[str, tk.StringVar] = {}
        for field in _AIRCRAFT_BOOL_FIELDS:
            val = entry.get(field)
            var = tk.StringVar(value=str(val).lower() if isinstance(val, bool) else ("" if val is None else str(val)))
            self._bool_vars[field] = var
            row = ttk.Frame(interior)
            row.pack(anchor="w", fill=tk.X, pady=(0, 4))
            ttk.Label(row, text=field, width=26).pack(side=tk.LEFT)
            ttk.Combobox(row, textvariable=var, values=["true", "false", ""], state="readonly", width=10).pack(side=tk.LEFT)

        ttk.Separator(interior, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=6)

        # Numeric fields
        self._num_vars: dict[str, tk.StringVar] = {}
        for field in _AIRCRAFT_NUM_FIELDS:
            val = entry.get(field)
            var = tk.StringVar(value=str(val) if val is not None else "")
            self._num_vars[field] = var
            row = ttk.Frame(interior)
            row.pack(anchor="w", fill=tk.X, pady=(0, 4))
            ttk.Label(row, text=field, width=26).pack(side=tk.LEFT)
            ttk.Entry(row, textvariable=var, width=12).pack(side=tk.LEFT)

        ttk.Separator(interior, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=6)

        # List fields (loadableVehiclesBLUE / loadableVehiclesRED)
        self._list_vars: dict[str, list[tk.StringVar]] = {}
        self._list_frames: dict[str, ttk.Frame] = {}
        for field in _AIRCRAFT_LIST_FIELDS:
            ttk.Label(interior, text=field, font=("", 9, "bold")).pack(anchor="w")
            items_frame = ttk.Frame(interior)
            items_frame.pack(anchor="w", fill=tk.X, pady=(0, 4))
            self._list_frames[field] = items_frame
            self._list_vars[field] = []
            for item in entry.get(field) or []:
                self._add_list_item(field, str(item))
            # Add row
            add_row = ttk.Frame(interior)
            add_row.pack(anchor="w", fill=tk.X, pady=(0, 8))
            add_var = tk.StringVar()
            add_entry = ttk.Entry(add_row, textvariable=add_var, width=20)
            add_entry.pack(side=tk.LEFT)
            ttk.Button(add_row, text="+", width=3,
                       command=lambda f=field, v=add_var: self._on_list_add(f, v)).pack(side=tk.LEFT, padx=2)  # type: ignore[misc]

        # Error label
        self._error_var = tk.StringVar()
        ttk.Label(interior, textvariable=self._error_var, foreground="red", wraplength=350).pack(anchor="w", pady=(4, 0))

        # Buttons
        btn_frame = ttk.Frame(interior)
        btn_frame.pack(anchor="w", pady=(10, 0))
        ttk.Button(btn_frame, text=t("tui.btn.apply"), command=self._apply).pack(side=tk.LEFT, padx=(0, 4))
        if state == "deleted":
            ttk.Button(btn_frame, text=t("tui.btn.restore"), command=self._restore).pack(side=tk.LEFT, padx=(0, 4))
        elif not is_new:
            ttk.Button(btn_frame, text=t("tui.btn.delete"), command=self._delete).pack(side=tk.LEFT, padx=(0, 4))
        ttk.Button(btn_frame, text=t("tui.btn.cancel"), command=self._on_cancel).pack(side=tk.LEFT)

    def _add_list_item(self, field: str, value: str) -> None:
        var = tk.StringVar(value=value)
        self._list_vars[field].append(var)
        frame = self._list_frames[field]
        row = ttk.Frame(frame)
        row.pack(anchor="w", fill=tk.X, pady=(0, 2))
        ttk.Entry(row, textvariable=var, width=22).pack(side=tk.LEFT)
        ttk.Button(row, text="x", width=2,
                   command=lambda r=row, v=var, f=field: self._on_list_remove(f, v, r)).pack(side=tk.LEFT, padx=2)  # type: ignore[misc]

    def _on_list_add(self, field: str, entry_var: tk.StringVar) -> None:
        val = entry_var.get().strip()
        if val:
            self._add_list_item(field, val)
            entry_var.set("")

    def _on_list_remove(self, field: str, var: tk.StringVar, row: ttk.Frame) -> None:
        if var in self._list_vars[field]:
            self._list_vars[field].remove(var)
        row.destroy()

    def set_error(self, msg: str) -> None:
        self._error_var.set(msg)

    def _collect_type_name(self) -> str:
        if self._is_new and self._type_picker is not None:
            return self._type_picker.get().strip()
        return self._type_name

    def _collect(self) -> dict:
        entry: dict = {}
        for field, var in self._bool_vars.items():
            raw = var.get().strip().lower()
            if raw in ("true", "false"):
                entry[field] = raw == "true"
        for field, var in self._num_vars.items():
            v = coerce(var.get())
            if v is not None:
                entry[field] = v
        for field, vars_list in self._list_vars.items():
            items = [v.get().strip() for v in vars_list if v.get().strip()]
            if items:
                entry[field] = items
        return entry

    def _apply(self) -> None:
        self._error_var.set("")
        type_name = self._collect_type_name()
        if not type_name:
            self._error_var.set("Type name required")
            return
        entry = self._collect()
        self._on_apply(type_name, entry)

    def _delete(self) -> None:
        self._on_delete(self._type_name)

    def _restore(self) -> None:
        self._on_restore(self._type_name)


_TROOP_COUNT_FIELDS = ("inf", "mg", "at", "aa", "mortar", "jtac")


class TroopForm(ttk.Frame):
    """Editor panel for one troop group entry."""

    def __init__(
        self,
        parent,
        *,
        entry: dict,
        state: str,
        on_apply: Callable,
        on_delete: Callable,
        on_restore: Callable,
        on_cancel: Callable,
    ) -> None:
        super().__init__(parent, padding=12)
        self._state = state
        self._original_name = entry.get("name", "")
        self._on_apply = on_apply
        self._on_delete = on_delete
        self._on_restore = on_restore
        self._on_cancel = on_cancel

        title = self._original_name or t("tui.troop.new")
        ttk.Label(self, text=title, font=("", 11, "bold")).pack(anchor="w", pady=(0, 8))

        # name field
        self._name_var = tk.StringVar(value=self._original_name)
        self._add_field("name", self._name_var)

        # Count fields
        self._count_vars: dict[str, tk.StringVar] = {}
        for field in _TROOP_COUNT_FIELDS:
            val = entry.get(field)
            var = tk.StringVar(value=str(val) if val is not None else "")
            self._add_field(field, var)
            self._count_vars[field] = var

        # Inline error
        self._error_var = tk.StringVar()
        ttk.Label(self, textvariable=self._error_var, foreground="red").pack(anchor="w", pady=(4, 0))

        # Buttons
        btn_frame = ttk.Frame(self)
        btn_frame.pack(anchor="w", pady=(10, 0))
        ttk.Button(btn_frame, text=t("tui.btn.apply"), command=self._apply).pack(side=tk.LEFT, padx=(0, 4))
        if state == "deleted":
            ttk.Button(btn_frame, text=t("tui.btn.restore"), command=self._restore).pack(side=tk.LEFT, padx=(0, 4))
        else:
            ttk.Button(btn_frame, text=t("tui.btn.delete"), command=self._delete).pack(side=tk.LEFT, padx=(0, 4))
        ttk.Button(btn_frame, text=t("tui.btn.cancel"), command=self._on_cancel).pack(side=tk.LEFT)

    def _add_field(self, label: str, var: tk.StringVar) -> None:
        row = ttk.Frame(self)
        row.pack(anchor="w", fill=tk.X, pady=(0, 4))
        ttk.Label(row, text=label, width=10).pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=var, width=20).pack(side=tk.LEFT)

    def set_error(self, msg: str) -> None:
        self._error_var.set(msg)

    def _collect(self) -> dict:
        entry: dict = {}
        name = self._name_var.get().strip()
        if name:
            entry["name"] = name
        for field, var in self._count_vars.items():
            v = coerce(var.get())
            if v is not None:
                entry[field] = v
        return entry

    def _apply(self) -> None:
        self._error_var.set("")
        self._on_apply(self._collect(), self._original_name)

    def _delete(self) -> None:
        self._on_delete(self._original_name)

    def _restore(self) -> None:
        self._on_restore(self._original_name)
