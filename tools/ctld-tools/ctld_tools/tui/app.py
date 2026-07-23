"""The ctld-tools GUI — Mission Maker catalogue editor.

Full catalogue tree on the left (all CTLD scalars with 4 visual states).
Selecting a scalar opens its editor form in the right pane. Footer: Save /
Generate / Inject + live validation status. Ctrl+Z/Y undo/redo.
"""

from __future__ import annotations

import tkinter as tk
import tkinter.font as tkfont
from pathlib import Path
from tkinter import ttk

import sv_ttk

from ctld_tools.editmodel import EditModel
from ctld_tools.i18n import current_language, t
from ctld_tools.reference import Reference, dict_to_zone, zone_to_dict
from ctld_tools.tui.forms import (
    AircraftForm,
    CrateForm,
    ScalarForm,
    StringEntryForm,
    TroopForm,
    VehicleWeightForm,
    ZoneForm,
)
from ctld_tools.validate import ERROR


class CtldToolsApp:
    USER_CONFIG_NAME = "user-config.yaml"
    USER_CONFIG_LUA = "CTLD_userConfig.lua"

    def __init__(
        self,
        yaml_path: str | Path | None = None,
        src: str | Path | None = None,
        _test_mode: bool = False,
    ) -> None:
        self._yaml_path = Path(yaml_path) if yaml_path else Path(self.USER_CONFIG_NAME)
        ref = Reference.from_src(src) if src else Reference.from_embedded()
        self.model = EditModel.load(self._yaml_path, ref=ref) if self._yaml_path.exists() else EditModel(ref=ref)
        self._current_key: str | None = None
        self._current_form: ScalarForm | CrateForm | TroopForm | AircraftForm | ZoneForm | StringEntryForm | VehicleWeightForm | None = None
        self._current_context: dict | None = None
        self._tree_tip: tk.Toplevel | None = None
        self._tree_tip_iid: str | None = None

        self.root = tk.Tk()
        self.root.title(t("app.title"))
        self.root.minsize(900, 600)
        sv_ttk.set_theme("light")
        if _test_mode:
            self.root.withdraw()

        self._build_ui()
        self._rebuild_tree()
        self._refresh_status()

    def _build_ui(self) -> None:
        self._paned = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL, name="paned")
        self._paned.pack(fill=tk.BOTH, expand=True)

        # Left: catalogue tree
        tree_frame = ttk.Frame(self._paned, name="tree_frame")
        self._tree = ttk.Treeview(tree_frame, show="tree", selectmode="browse", name="catalogue")
        self._tree.tag_configure("modified", font=("", 0, "bold"))
        self._tree.tag_configure("default", font=("", 0, ""))
        self._tree.tag_configure("added", foreground="#2a9d2a")
        base_font = tkfont.nametofont("TkDefaultFont")
        strike_font = tkfont.Font(font=base_font, overstrike=True)
        self._tree.tag_configure("deleted", font=strike_font, foreground="gray")
        tree_scroll = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=self._tree.yview)
        self._tree.configure(yscrollcommand=tree_scroll.set)
        self._tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        tree_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self._tree.bind("<<TreeviewSelect>>", self._on_tree_select)
        self._tree.bind("<Motion>", self._on_tree_motion)
        self._tree.bind("<Leave>", self._on_tree_leave)
        self._paned.add(tree_frame, weight=1)

        # Right: editor form area
        self._form_frame = ttk.Frame(self._paned, name="form_frame")
        self._paned.add(self._form_frame, weight=2)

        # Footer
        footer = ttk.Frame(self.root, name="footer", relief=tk.GROOVE, padding=4)
        footer.pack(fill=tk.X, side=tk.BOTTOM)
        self._status_var = tk.StringVar(value=t("tui.validation.ok"))
        ttk.Label(footer, textvariable=self._status_var, name="status").pack(side=tk.LEFT, padx=4)
        self._inject_btn = ttk.Button(footer, text=t("tui.btn.inject"), name="btn_inject", command=self._inject)
        self._inject_btn.pack(side=tk.RIGHT, padx=2)
        self._gen_btn = ttk.Button(footer, text=t("tui.btn.generate"), name="btn_generate", command=self._generate)
        self._gen_btn.pack(side=tk.RIGHT, padx=2)
        self._save_btn = ttk.Button(footer, text=t("tui.btn.save"), name="btn_save", command=self._save)
        self._save_btn.pack(side=tk.RIGHT, padx=2)

        # Key bindings
        self.root.bind("<Control-z>", self._undo)
        self.root.bind("<Control-y>", self._redo)

        # Initial placeholder in form pane
        self._show_form_hint()

    def _show_form_hint(self) -> None:
        ttk.Label(
            self._form_frame,
            text=t("tui.form.select_hint"),
            foreground="gray",
        ).pack(expand=True)

    def _clear_form(self) -> None:
        for child in self._form_frame.winfo_children():
            child.destroy()
        self._current_key = None
        self._current_form = None
        self._current_context = None

    # --- tree tooltips -----------------------------------------------------------

    def _on_tree_motion(self, event) -> None:
        iid = self._tree.identify_row(event.y)
        if iid == self._tree_tip_iid:
            return
        self._hide_tree_tip()
        self._tree_tip_iid = iid
        if not iid:
            return
        text = self._tree_tooltip_text(iid)
        if not text:
            return
        x = self._tree.winfo_rootx() + event.x + 16
        y = self._tree.winfo_rooty() + event.y + 16
        self._tree_tip = tk.Toplevel(self._tree)
        self._tree_tip.wm_overrideredirect(True)
        self._tree_tip.wm_geometry(f"+{x}+{y}")
        tk.Label(
            self._tree_tip,
            text=text,
            background="#ffffc0",
            relief=tk.SOLID,
            borderwidth=1,
            wraplength=300,
            justify=tk.LEFT,
            padx=4,
            pady=2,
        ).pack()

    def _on_tree_leave(self, event=None) -> None:  # noqa: ARG002
        self._hide_tree_tip()

    def _hide_tree_tip(self) -> None:
        if self._tree_tip:
            self._tree_tip.destroy()
            self._tree_tip = None
        self._tree_tip_iid = None

    def _tree_tooltip_text(self, iid: str) -> str | None:
        """Return a description string for a tree node iid, or None if unavailable."""
        if iid.startswith("scalar:"):
            key = iid[len("scalar:"):]
            return self.model.ref.setting_description(key, current_language())
        return None

    # --- tree --------------------------------------------------------------------

    def _rebuild_tree(self) -> None:
        self._hide_tree_tip()
        selected = self._tree.selection()
        prev_iid = selected[0] if selected else None

        self._tree.delete(*self._tree.get_children())
        overrides = self.model.config.get("settings", {})
        scalars = self.model.ref.scalar_settings()

        params = self._tree.insert("", "end", iid="params", text=t("tui.section.parameters"), open=True)

        _FAMILY_ORDER = [
            "general", "crates", "troops", "boarding", "jtac",
            "smoke", "beacon", "fob", "recon", "mines", "aa", "soldier_weights",
        ]

        # Bucket scalars by family, preserving sorted order within each bucket
        from collections import defaultdict
        family_std: dict[str | None, list[str]] = defaultdict(list)
        family_adv: dict[str | None, list[str]] = defaultdict(list)
        for key in sorted(scalars):
            grp = self.model.ref.setting_group(key)
            if self.model.ref.is_standard(key):
                family_std[grp].append(key)
            else:
                family_adv[grp].append(key)

        # All groups that have at least one setting
        all_groups: list[str | None] = []
        for g in _FAMILY_ORDER:
            if family_std[g] or family_adv[g]:
                all_groups.append(g)
        # Ungrouped settings go last under a catch-all node
        if family_std[None] or family_adv[None]:
            all_groups.append(None)

        for grp in all_groups:
            grp_key = grp or "other"
            grp_iid = f"params_family:{grp_key}"
            grp_label = t(f"tui.family.{grp_key}")
            grp_node = self._tree.insert(params, "end", iid=grp_iid, text=grp_label, open=False)

            if family_std[grp]:
                std_node = self._tree.insert(grp_node, "end", iid=f"params_std:{grp_key}",
                                             text=t("tui.section.standard"), open=False)
                for key in family_std[grp]:
                    is_modified = key in overrides
                    effective = overrides[key] if is_modified else scalars[key]
                    label = f"{key} = {effective}{'  *' if is_modified else ''}"
                    tag = "modified" if is_modified else "default"
                    self._tree.insert(std_node, "end", iid=f"scalar:{key}", text=label, tags=(tag,))

            if family_adv[grp]:
                adv_node = self._tree.insert(grp_node, "end", iid=f"params_adv:{grp_key}",
                                             text=t("tui.section.advanced"), open=False)
                for key in family_adv[grp]:
                    is_modified = key in overrides
                    effective = overrides[key] if is_modified else scalars[key]
                    label = f"{key} = {effective}{'  *' if is_modified else ''}"
                    tag = "modified" if is_modified else "default"
                    self._tree.insert(adv_node, "end", iid=f"scalar:{key}", text=label, tags=(tag,))

        # --- Crates section ---
        self._rebuild_crates_section()

        # --- Troops section ---
        self._rebuild_troops_section()

        # --- Aircraft section ---
        self._rebuild_aircraft_section()

        # --- Zones section ---
        self._rebuild_zones_section()

        # --- Mission Lists section ---
        self._rebuild_mission_lists_section()

        # --- Vehicle Weights section ---
        self._rebuild_vehicle_weights_section()

        # Restore selection
        if prev_iid and self._tree.exists(prev_iid):
            self._tree.selection_set(prev_iid)
            self._tree.see(prev_iid)

    def _rebuild_crates_section(self) -> None:
        catalogue = self.model.ref.spawnable_crates()
        adds = self.model.config.get("crates", {}).get("add", [])
        removes = self.model.config.get("crates", {}).get("remove", [])
        patches = self.model.config.get("crates", {}).get("patch", [])

        crates_node = self._tree.insert("", "end", iid="crates", text=t("tui.section.crates"), open=False)

        for family, entries in catalogue.items():
            fam_iid = f"crate_family:{family}"
            self._tree.insert(crates_node, "end", iid=fam_iid, text=family, open=False)
            for entry in entries:
                desc = entry.get("desc", "?")
                weight = entry.get("weight")
                if weight is None:
                    # mixedSet entries have no weight — skip (not individually editable)
                    continue
                iid = f"crate:{family}:{weight}"
                if desc in removes or weight in removes:
                    state = "deleted"
                    label = desc
                elif any(p.get("name") == desc for p in patches):
                    state = "modified"
                    label = f"{desc}  *"
                else:
                    state = "default"
                    label = desc
                self._tree.insert(fam_iid, "end", iid=iid, text=label, tags=(state,))

        # Added crates under their section family
        for idx, add_entry in enumerate(adds):
            section = add_entry.get("section", "Support")
            fam_iid = f"crate_family:{section}"
            if not self._tree.exists(fam_iid):
                self._tree.insert(crates_node, "end", iid=fam_iid, text=section, open=False)
            add_name = add_entry.get("name") or add_entry.get("desc") or "?"
            add_iid = f"crate_add:{idx}"
            self._tree.insert(fam_iid, "end", iid=add_iid, text=f"{add_name}  +", tags=("added",))

    def _rebuild_troops_section(self) -> None:
        groups = self.model.ref.loadable_groups()
        adds = self.model.config.get("troops", {}).get("add", [])
        removes = self.model.config.get("troops", {}).get("remove", [])
        patches = self.model.config.get("troops", {}).get("patch", [])

        troops_node = self._tree.insert("", "end", iid="troops", text=t("tui.section.troops"), open=False)

        for group in groups:
            name = group.get("name", "?")
            iid = f"troop:{name}"
            if name in removes:
                state, label = "deleted", name
            elif any(p.get("name") == name for p in patches):
                state, label = "modified", f"{name}  *"
            else:
                state, label = "default", name
            self._tree.insert(troops_node, "end", iid=iid, text=label, tags=(state,))

        for idx, add_entry in enumerate(adds):
            add_name = add_entry.get("name", "?")
            self._tree.insert(troops_node, "end", iid=f"troop_add:{idx}", text=f"{add_name}  +", tags=("added",))

    def _rebuild_aircraft_section(self) -> None:
        catalogue = self.model.ref.aircraft_capabilities()
        caps_config = self.model.config.get("capabilities") or {}
        sets = caps_config.get("set") or {}
        removes = caps_config.get("remove") or []

        aircraft_node = self._tree.insert("", "end", iid="aircraft", text=t("tui.section.aircraft"), open=False)

        for type_name in sorted(catalogue):
            iid = f"aircraft:{type_name}"
            if type_name in removes:
                state, label = "deleted", type_name
            elif type_name in sets:
                state, label = "modified", f"{type_name}  *"
            else:
                state, label = "default", type_name
            self._tree.insert(aircraft_node, "end", iid=iid, text=label, tags=(state,))

        # User-added aircraft
        for type_name in sorted(sets):
            if type_name not in catalogue:
                iid = f"aircraft:{type_name}"
                self._tree.insert(aircraft_node, "end", iid=iid, text=f"{type_name}  +", tags=("added",))

    def _rebuild_zones_section(self) -> None:
        zones_node = self._tree.insert("", "end", iid="zones", text=t("tui.section.zones"), open=False)
        zone_defs = [
            ("troopZones", "tui.section.troop_zones"),
            ("wpZones", "tui.section.wp_zones"),
            ("AIZones", "tui.section.ai_zones"),
        ]
        for zone_type, label_key in zone_defs:
            sub_iid = f"zone_type:{zone_type}"
            self._tree.insert(zones_node, "end", iid=sub_iid, text=t(label_key), open=False)
            defaults = self.model.ref.default_zones(zone_type)
            added = self.model.config.get("arrays", {}).get(zone_type, [])
            # Default entries (read-only)
            for pos_entry in defaults:
                name = pos_entry[0] if pos_entry else "?"
                iid = f"zone_default:{zone_type}:{name}"
                self._tree.insert(sub_iid, "end", iid=iid, text=name, tags=("default",))
            # User-added entries
            for idx, pos_entry in enumerate(added):
                name = pos_entry[0] if pos_entry else "?"
                iid = f"zone_add:{zone_type}:{idx}"
                self._tree.insert(sub_iid, "end", iid=iid, text=f"{name}  +", tags=("added",))

    def _rebuild_mission_lists_section(self) -> None:
        lists_node = self._tree.insert("", "end", iid="mission_lists", text=t("tui.section.mission_lists"), open=False)
        list_defs = [
            ("transportPilotNames", "tui.section.transport_pilots"),
            ("extractableGroups", "tui.section.extract_groups"),
            ("logisticUnits", "tui.section.logistic_units"),
        ]
        for setting, label_key in list_defs:
            sub_iid = f"mlist:{setting}"
            self._tree.insert(lists_node, "end", iid=sub_iid, text=t(label_key), open=False)
            defaults = self.model.ref.default_list(setting)
            added = self.model.config.get("arrays", {}).get(setting, [])
            for name in defaults:
                iid = f"mlist_default:{setting}:{name}"
                self._tree.insert(sub_iid, "end", iid=iid, text=name, tags=("default",))
            for idx, name in enumerate(added):
                iid = f"mlist_add:{setting}:{idx}"
                self._tree.insert(sub_iid, "end", iid=iid, text=f"{name}  +", tags=("added",))

    def _rebuild_vehicle_weights_section(self) -> None:
        vw_node = self._tree.insert("", "end", iid="vehicle_weights", text=t("tui.section.vehicle_weights"), open=False)
        defaults = self.model.ref.vehicle_weights()
        vw_config = self.model.config.get("vehicleWeights") or {}
        sets = vw_config.get("set") or {}
        removes = vw_config.get("remove") or []

        for unit_name in sorted(defaults):
            iid = f"vw:{unit_name}"
            if unit_name in removes:
                state, label = "deleted", unit_name
            elif unit_name in sets:
                state, label = "modified", f"{unit_name}  *"
            else:
                state, label = "default", unit_name
            self._tree.insert(vw_node, "end", iid=iid, text=label, tags=(state,))

        for unit_name in sorted(sets):
            if unit_name not in defaults:
                iid = f"vw:{unit_name}"
                self._tree.insert(vw_node, "end", iid=iid, text=f"{unit_name}  +", tags=("added",))

    def _on_tree_select(self, event=None) -> None:  # noqa: ARG002
        sel = self._tree.selection()
        if not sel:
            return
        iid = sel[0]
        if iid.startswith("scalar:"):
            self._open_scalar_form(iid[len("scalar:") :])
        elif iid.startswith("crate:"):
            # "crate:{family}:{weight}"
            _, family, weight_str = iid.split(":", 2)
            self._open_crate_form(family, float(weight_str))
        elif iid.startswith("crate_add:"):
            idx = int(iid[len("crate_add:") :])
            self._open_crate_add_form(idx)
        elif iid.startswith("crate_family:"):
            family = iid[len("crate_family:") :]
            self._show_family_actions(family)
        elif iid.startswith("troop_add:"):
            idx = int(iid[len("troop_add:") :])
            self._open_troop_add_form(idx)
        elif iid.startswith("troop:"):
            name = iid[len("troop:") :]
            self._open_troop_form(name)
        elif iid == "troops":
            self._show_troop_add_button()
        elif iid.startswith("aircraft:"):
            type_name = iid[len("aircraft:"):]
            self._open_aircraft_form(type_name)
        elif iid == "aircraft":
            self._show_aircraft_add_button()
        elif iid.startswith("zone_default:"):
            _, zone_type, name = iid.split(":", 2)
            self._open_zone_default_view(zone_type, name)
        elif iid.startswith("zone_add:"):
            _, zone_type, idx_str = iid.split(":", 2)
            self._open_zone_add_form(zone_type, int(idx_str))
        elif iid.startswith("zone_type:"):
            zone_type = iid[len("zone_type:"):]
            self._show_zone_add_button(zone_type)
        elif iid.startswith("mlist_default:"):
            parts = iid.split(":", 2)
            self._show_mlist_default_view(parts[2] if len(parts) > 2 else "")
        elif iid.startswith("mlist_add:"):
            _, setting, idx_str = iid.split(":", 2)
            self._open_mlist_add_form(setting, int(idx_str))
        elif iid.startswith("mlist:"):
            setting = iid[len("mlist:"):]
            self._show_mlist_add_button(setting)
        elif iid.startswith("vw:"):
            unit_name = iid[len("vw:"):]
            self._open_vehicle_weight_form(unit_name)
        elif iid == "vehicle_weights":
            self._show_vw_add_button()
        else:
            self._clear_form()
            self._show_form_hint()

    # --- mission list forms ------------------------------------------------------

    def _show_mlist_default_view(self, name: str) -> None:
        self._clear_form()
        self._current_context = {"type": "mlist_default", "name": name}
        ttk.Label(self._form_frame, text=name, font=("", 11, "bold")).pack(
            anchor="w", padx=12, pady=(12, 4)
        )
        ttk.Label(self._form_frame, text=t("tui.mlist.default_note"), foreground="gray").pack(anchor="w", padx=12)

    def _open_mlist_add_form(self, setting: str, idx: int) -> None:
        self._clear_form()
        added = self.model.config.get("arrays", {}).get(setting, [])
        if idx >= len(added):
            return
        value = added[idx]
        self._current_context = {"type": "mlist_add", "setting": setting, "idx": idx}
        label_map = {
            "transportPilotNames": "tui.section.transport_pilots",
            "extractableGroups": "tui.section.extract_groups",
            "logisticUnits": "tui.section.logistic_units",
        }
        label = t(label_map.get(setting, "tui.section.mission_lists"))
        form = StringEntryForm(
            self._form_frame,
            label=label,
            value=str(value),
            state="added",
            on_apply=lambda v: self._on_mlist_add_apply(setting, idx, v),
            on_delete=lambda: self._on_mlist_add_delete(setting, idx),
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _show_mlist_add_button(self, setting: str) -> None:
        self._clear_form()
        self._current_context = {"type": "mlist_node", "setting": setting}
        label_map = {
            "transportPilotNames": "tui.section.transport_pilots",
            "extractableGroups": "tui.section.extract_groups",
            "logisticUnits": "tui.section.logistic_units",
        }
        label = t(label_map.get(setting, "tui.section.mission_lists"))
        ttk.Label(self._form_frame, text=label, font=("", 11, "bold")).pack(anchor="w", padx=12, pady=(12, 4))
        ttk.Button(
            self._form_frame,
            text=t("tui.mlist.add_btn"),
            command=lambda: self._open_new_mlist_form(setting),
        ).pack(anchor="w", padx=12, pady=4)

    def _open_new_mlist_form(self, setting: str) -> None:
        self._clear_form()
        self._current_context = {"type": "mlist_new", "setting": setting}
        label_map = {
            "transportPilotNames": "tui.section.transport_pilots",
            "extractableGroups": "tui.section.extract_groups",
            "logisticUnits": "tui.section.logistic_units",
        }
        label = t(label_map.get(setting, "tui.section.mission_lists"))
        form = StringEntryForm(
            self._form_frame,
            label=label,
            value="",
            state="added",
            on_apply=lambda v: self._on_mlist_new_apply(setting, v),
            on_delete=lambda: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _on_mlist_new_apply(self, setting: str, value: str) -> None:
        if value:
            self.model.append_array(setting, value)
            self._rebuild_tree()
            self._refresh_status()

    def _on_mlist_add_apply(self, setting: str, idx: int, value: str) -> None:
        self.model.update_entry(("arrays", setting, idx), value)
        self._rebuild_tree()
        self._refresh_status()

    def _on_mlist_add_delete(self, setting: str, idx: int) -> None:
        self.model.delete_entry(("arrays", setting, idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    # --- vehicle weight forms ----------------------------------------------------

    def _open_vehicle_weight_form(self, unit_name: str) -> None:
        self._clear_form()
        defaults = self.model.ref.vehicle_weights()
        vw_config = self.model.config.get("vehicleWeights") or {}
        sets = vw_config.get("set") or {}
        removes = vw_config.get("remove") or []

        if unit_name in removes:
            state = "deleted"
            weight = defaults.get(unit_name)
        elif unit_name in sets:
            state = "modified" if unit_name in defaults else "added"
            weight = sets[unit_name]
        else:
            state = "default"
            weight = defaults.get(unit_name)

        self._current_context = {"type": "vw", "unit_name": unit_name}
        form = VehicleWeightForm(
            self._form_frame,
            unit_name=unit_name,
            weight=weight,
            state=state,
            on_apply=self._on_vw_apply,
            on_delete=self._on_vw_delete,
            on_restore=self._on_vw_restore,
            on_cancel=self._on_form_cancel,
            is_new=False,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _show_vw_add_button(self) -> None:
        self._clear_form()
        self._current_context = {"type": "vw_node"}
        ttk.Label(self._form_frame, text=t("tui.section.vehicle_weights"), font=("", 11, "bold")).pack(
            anchor="w", padx=12, pady=(12, 4)
        )
        ttk.Button(self._form_frame, text=t("tui.vehicle.add_btn"), command=self._open_new_vw_form).pack(
            anchor="w", padx=12, pady=4
        )

    def _open_new_vw_form(self) -> None:
        self._clear_form()
        self._current_context = {"type": "vw_new"}
        form = VehicleWeightForm(
            self._form_frame,
            unit_name="",
            weight=None,
            state="default",
            on_apply=self._on_vw_apply,
            on_delete=lambda _: None,
            on_restore=lambda _: None,
            on_cancel=self._on_form_cancel,
            is_new=True,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _on_vw_apply(self, unit_name: str, weight) -> None:
        self.model.set_vehicle_weight(unit_name, weight)
        self._rebuild_tree()
        self._refresh_status()

    def _on_vw_delete(self, unit_name: str) -> None:
        self.model.remove_vehicle_weight(unit_name)
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _on_vw_restore(self, unit_name: str) -> None:
        removes = self.model.config.get("vehicleWeights", {}).get("remove", [])
        idx = next((i for i, r in enumerate(removes) if r == unit_name), None)
        if idx is not None:
            self.model.delete_entry(("vehicleWeights", "remove", idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    # --- zone forms --------------------------------------------------------------

    def _open_zone_default_view(self, zone_type: str, name: str) -> None:
        """Show read-only view for a default zone entry."""
        self._clear_form()
        defaults = self.model.ref.default_zones(zone_type)
        fields = self.model.ref.zone_fields(zone_type)
        pos_entry = next((e for e in defaults if e and e[0] == name), None)
        if pos_entry is None:
            return
        named = zone_to_dict(fields, pos_entry)
        self._current_context = {"type": "zone_default", "zone_type": zone_type, "name": name}
        form = ZoneForm(
            self._form_frame,
            zone_type=zone_type,
            fields=fields,
            entry=named,
            state="default",
            on_apply=lambda zt, n: None,
            on_delete=lambda zt: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _open_zone_add_form(self, zone_type: str, idx: int) -> None:
        self._clear_form()
        added = self.model.config.get("arrays", {}).get(zone_type, [])
        if idx >= len(added):
            return
        fields = self.model.ref.zone_fields(zone_type)
        named = zone_to_dict(fields, added[idx])
        self._current_context = {"type": "zone_add", "zone_type": zone_type, "idx": idx}
        form = ZoneForm(
            self._form_frame,
            zone_type=zone_type,
            fields=fields,
            entry=named,
            state="added",
            on_apply=lambda zt, n: self._on_zone_add_apply(zt, idx, n),
            on_delete=lambda zt: self._on_zone_add_delete(zt, idx),
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _show_zone_add_button(self, zone_type: str) -> None:
        self._clear_form()
        self._current_context = {"type": "zone_type", "zone_type": zone_type}
        label_map = {
            "troopZones": "tui.section.troop_zones",
            "wpZones": "tui.section.wp_zones",
            "AIZones": "tui.section.ai_zones",
        }
        label = t(label_map.get(zone_type, "tui.section.zones"))
        ttk.Label(self._form_frame, text=label, font=("", 11, "bold")).pack(anchor="w", padx=12, pady=(12, 4))
        ttk.Button(
            self._form_frame,
            text=t("tui.zone.add_btn"),
            command=lambda: self._open_new_zone_form(zone_type),
        ).pack(anchor="w", padx=12, pady=4)

    def _open_new_zone_form(self, zone_type: str) -> None:
        self._clear_form()
        self._current_context = {"type": "zone_new", "zone_type": zone_type}
        fields = self.model.ref.zone_fields(zone_type)
        form = ZoneForm(
            self._form_frame,
            zone_type=zone_type,
            fields=fields,
            entry={},
            state="added",
            on_apply=self._on_zone_new_apply,
            on_delete=lambda zt: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _on_zone_new_apply(self, zone_type: str, named: dict) -> None:
        fields = self.model.ref.zone_fields(zone_type)
        positional = dict_to_zone(fields, named)
        self.model.append_array(zone_type, positional)
        self._rebuild_tree()
        self._refresh_status()

    def _on_zone_add_apply(self, zone_type: str, idx: int, named: dict) -> None:
        fields = self.model.ref.zone_fields(zone_type)
        positional = dict_to_zone(fields, named)
        self.model.update_entry(("arrays", zone_type, idx), positional)
        self._rebuild_tree()
        self._refresh_status()

    def _on_zone_add_delete(self, zone_type: str, idx: int) -> None:
        self.model.delete_entry(("arrays", zone_type, idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _open_scalar_form(self, key: str) -> None:
        self._clear_form()
        scalars = self.model.ref.scalar_settings()
        default = scalars.get(key)
        current = self.model.config.get("settings", {}).get(key, default)
        choices = self.model.ref.enum_choices(key)
        description = self.model.ref.setting_description(key, current_language())

        self._current_key = key
        form = ScalarForm(
            self._form_frame,
            key=key,
            default=default,
            current=current,
            choices=choices,
            description=description,
            on_apply=self._on_scalar_apply,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

        # Show any existing findings for this key
        self._show_form_findings(key)

    def _show_form_findings(self, key: str) -> None:
        if self._current_form is None:
            return
        for finding in self.model.findings:
            if key in finding.where:
                self._current_form.set_error(finding.message)
                return

    def _on_scalar_apply(self, key: str, value) -> None:
        self.model.set_setting(key, value)
        self._rebuild_tree()
        self._refresh_status()
        self._open_scalar_form(key)
        self._show_form_findings(key)

    def _on_form_cancel(self) -> None:
        self._clear_form()
        self._show_form_hint()
        self._tree.selection_remove(*self._tree.selection())

    # --- crate forms -------------------------------------------------------------

    def _open_crate_form(self, family: str, weight: float) -> None:
        """Open CrateForm for an existing catalogue crate."""
        self._clear_form()
        catalogue = self.model.ref.spawnable_crates()
        entry = next((e for e in catalogue.get(family, []) if e.get("weight") == weight), None)
        if entry is None:
            return
        # Merge with patches
        effective = dict(entry)
        desc = entry.get("desc", "")
        patches = self.model.config.get("crates", {}).get("patch", [])
        for patch in patches:
            if patch.get("name") == desc:
                effective.update({k: v for k, v in patch.items() if k not in ("name",)})
        # Determine state
        removes = self.model.config.get("crates", {}).get("remove", [])
        if desc in removes or weight in removes:
            state = "deleted"
        elif any(p.get("name") == desc for p in patches):
            state = "modified"
        else:
            state = "default"
        self._current_context = {"type": "crate", "family": family, "weight": weight}
        form = CrateForm(
            self._form_frame,
            family=family,
            entry=effective,
            state=state,
            on_apply=self._on_crate_apply,
            on_delete=self._on_crate_delete,
            on_restore=self._on_crate_restore,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _open_crate_add_form(self, idx: int) -> None:
        """Open CrateForm for an already-added (user-created) crate."""
        self._clear_form()
        adds = self.model.config.get("crates", {}).get("add", [])
        if idx >= len(adds):
            return
        add_entry = adds[idx]
        # Normalize: add_crate uses "name" but CrateForm uses "desc" too
        entry = dict(add_entry)
        if "name" in entry and "desc" not in entry:
            entry["desc"] = entry["name"]
        family = entry.get("section", "Support")
        self._current_context = {"type": "crate_add", "idx": idx}
        form = CrateForm(
            self._form_frame,
            family=family,
            entry=entry,
            state="added",
            on_apply=self._on_crate_add_apply,
            on_delete=lambda d, w: self._on_crate_add_delete(idx),
            on_restore=lambda d: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _show_family_actions(self, family: str) -> None:
        """Show an 'Add crate' button when clicking a family node."""
        self._clear_form()
        self._current_context = {"type": "crate_family", "family": family}
        ttk.Label(self._form_frame, text=f"{family}", font=("", 11, "bold")).pack(anchor="w", padx=12, pady=(12, 4))
        ttk.Button(
            self._form_frame,
            text=t("tui.crate.add_btn", family=family),
            command=lambda: self._open_new_crate_form(family),
        ).pack(anchor="w", padx=12, pady=4)

    def _open_new_crate_form(self, family: str) -> None:
        """Open a blank CrateForm to add a new crate to a family."""
        self._clear_form()
        self._current_context = {"type": "crate_new", "family": family}
        form = CrateForm(
            self._form_frame,
            family=family,
            entry={},
            state="default",
            on_apply=self._on_crate_apply,
            on_delete=lambda d, w: None,
            on_restore=lambda d: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _on_crate_apply(self, family: str, entry: dict, original_desc: str) -> None:
        if original_desc:
            # Editing an existing catalogue crate → patch
            patches = self.model.config.get("crates", {}).get("patch", [])
            existing_idx = next((i for i, p in enumerate(patches) if p.get("name") == original_desc), None)
            patch_entry = {"name": original_desc}
            patch_entry.update({k: v for k, v in entry.items() if k not in ("name", "desc", "section")})
            if existing_idx is not None:
                self.model.update_entry(("crates", "patch", existing_idx), patch_entry)
            else:
                self.model.patch_crate(patch_entry)
        else:
            # New crate
            add_entry = {k: v for k, v in entry.items() if k != "desc"}
            if "desc" in entry and "name" not in add_entry:
                add_entry["name"] = entry["desc"]
            self.model.add_crate(add_entry)
        self._rebuild_tree()
        self._refresh_status()

    def _on_crate_add_apply(self, family: str, entry: dict, original_desc: str) -> None:  # noqa: ARG002
        """Apply changes to an already-added (user-created) crate."""
        ctx = self._current_context
        if ctx and ctx.get("type") == "crate_add":
            idx = ctx["idx"]
            add_entry = {k: v for k, v in entry.items() if k != "desc"}
            if "desc" in entry and "name" not in add_entry:
                add_entry["name"] = entry["desc"]
            self.model.update_entry(("crates", "add", idx), add_entry)
            self._rebuild_tree()
            self._refresh_status()

    def _on_crate_delete(self, desc: str, weight) -> None:  # noqa: ARG002
        self.model.remove_crate(desc)
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _on_crate_add_delete(self, idx: int) -> None:
        self.model.delete_entry(("crates", "add", idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _on_crate_restore(self, desc: str) -> None:
        removes = self.model.config.get("crates", {}).get("remove", [])
        idx = next((i for i, r in enumerate(removes) if r == desc), None)
        if idx is not None:
            self.model.delete_entry(("crates", "remove", idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    # --- troop forms -------------------------------------------------------------

    def _open_troop_form(self, name: str) -> None:
        self._clear_form()
        groups = self.model.ref.loadable_groups()
        group = next((g for g in groups if g.get("name") == name), None)
        if group is None:
            return
        # Merge with patches
        effective = dict(group)
        patches = self.model.config.get("troops", {}).get("patch", [])
        for patch in patches:
            if patch.get("name") == name:
                effective.update({k: v for k, v in patch.items() if k != "name"})
        removes = self.model.config.get("troops", {}).get("remove", [])
        state = (
            "deleted" if name in removes else ("modified" if any(p.get("name") == name for p in patches) else "default")
        )
        self._current_context = {"type": "troop", "name": name}
        form = TroopForm(
            self._form_frame,
            entry=effective,
            state=state,
            on_apply=self._on_troop_apply,
            on_delete=self._on_troop_delete,
            on_restore=self._on_troop_restore,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _open_troop_add_form(self, idx: int) -> None:
        self._clear_form()
        adds = self.model.config.get("troops", {}).get("add", [])
        if idx >= len(adds):
            return
        entry = dict(adds[idx])
        self._current_context = {"type": "troop_add", "idx": idx}
        form = TroopForm(
            self._form_frame,
            entry=entry,
            state="added",
            on_apply=lambda e, _orig: self._on_troop_add_apply(idx, e),
            on_delete=lambda _n: self._on_troop_add_delete(idx),
            on_restore=lambda _n: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _show_troop_add_button(self) -> None:
        self._clear_form()
        self._current_context = {"type": "troops_node"}
        ttk.Label(self._form_frame, text=t("tui.section.troops"), font=("", 11, "bold")).pack(
            anchor="w", padx=12, pady=(12, 4)
        )
        ttk.Button(self._form_frame, text=t("tui.troop.add_btn"), command=self._open_new_troop_form).pack(
            anchor="w", padx=12, pady=4
        )

    def _open_new_troop_form(self) -> None:
        self._clear_form()
        self._current_context = {"type": "troop_new"}
        form = TroopForm(
            self._form_frame,
            entry={},
            state="default",
            on_apply=self._on_troop_apply,
            on_delete=lambda _n: None,
            on_restore=lambda _n: None,
            on_cancel=self._on_form_cancel,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _on_troop_apply(self, entry: dict, original_name: str) -> None:
        if original_name:
            patches = self.model.config.get("troops", {}).get("patch", [])
            existing_idx = next((i for i, p in enumerate(patches) if p.get("name") == original_name), None)
            patch_entry = {"name": original_name}
            patch_entry.update({k: v for k, v in entry.items() if k != "name"})
            if existing_idx is not None:
                self.model.update_entry(("troops", "patch", existing_idx), patch_entry)
            else:
                self.model.patch_troop(patch_entry)
        else:
            self.model.add_troop(entry)
        self._rebuild_tree()
        self._refresh_status()

    def _on_troop_add_apply(self, idx: int, entry: dict) -> None:
        self.model.update_entry(("troops", "add", idx), entry)
        self._rebuild_tree()
        self._refresh_status()

    def _on_troop_delete(self, name: str) -> None:
        self.model.remove_troop(name)
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _on_troop_add_delete(self, idx: int) -> None:
        self.model.delete_entry(("troops", "add", idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _on_troop_restore(self, name: str) -> None:
        removes = self.model.config.get("troops", {}).get("remove", [])
        idx = next((i for i, r in enumerate(removes) if r == name), None)
        if idx is not None:
            self.model.delete_entry(("troops", "remove", idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    # --- aircraft forms ----------------------------------------------------------

    def _open_aircraft_form(self, type_name: str) -> None:
        self._clear_form()
        catalogue = self.model.ref.aircraft_capabilities()
        caps_config = self.model.config.get("capabilities") or {}
        sets = caps_config.get("set") or {}
        removes = caps_config.get("remove") or []

        if type_name in catalogue:
            base = dict(catalogue[type_name])
            if type_name in sets:
                base.update(sets[type_name])
            state = "deleted" if type_name in removes else ("modified" if type_name in sets else "default")
        else:
            base = dict(sets.get(type_name, {}))
            state = "added"

        self._current_context = {"type": "aircraft", "type_name": type_name}
        form = AircraftForm(
            self._form_frame,
            type_name=type_name,
            entry=base,
            state=state,
            on_apply=self._on_aircraft_apply,
            on_delete=self._on_aircraft_delete,
            on_restore=self._on_aircraft_restore,
            on_cancel=self._on_form_cancel,
            is_new=False,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _show_aircraft_add_button(self) -> None:
        self._clear_form()
        self._current_context = {"type": "aircraft_node"}
        ttk.Label(self._form_frame, text=t("tui.section.aircraft"), font=("", 11, "bold")).pack(
            anchor="w", padx=12, pady=(12, 4)
        )
        ttk.Button(self._form_frame, text=t("tui.aircraft.add_btn"), command=self._open_new_aircraft_form).pack(
            anchor="w", padx=12, pady=4
        )

    def _open_new_aircraft_form(self) -> None:
        self._clear_form()
        self._current_context = {"type": "aircraft_new"}
        form = AircraftForm(
            self._form_frame,
            type_name="",
            entry={},
            state="default",
            on_apply=self._on_aircraft_apply,
            on_delete=lambda _t: None,
            on_restore=lambda _t: None,
            on_cancel=self._on_form_cancel,
            is_new=True,
        )
        form.pack(fill=tk.BOTH, expand=True)
        self._current_form = form

    def _on_aircraft_apply(self, type_name: str, attribs: dict) -> None:
        self.model.set_aircraft(type_name, attribs)
        self._rebuild_tree()
        self._refresh_status()

    def _on_aircraft_delete(self, type_name: str) -> None:
        self.model.remove_aircraft(type_name)
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    def _on_aircraft_restore(self, type_name: str) -> None:
        removes = self.model.config.get("capabilities", {}).get("remove", [])
        idx = next((i for i, r in enumerate(removes) if r == type_name), None)
        if idx is not None:
            self.model.delete_entry(("capabilities", "remove", idx))
        self._rebuild_tree()
        self._refresh_status()
        self._clear_form()
        self._show_form_hint()

    # --- undo / redo -------------------------------------------------------------

    def _undo(self, event=None) -> None:  # noqa: ARG002
        if self.model.undo():
            ctx = self._current_context
            key = self._current_key
            self._rebuild_tree()
            self._refresh_status()
            if key:
                self._open_scalar_form(key)
            elif ctx and ctx.get("type") == "crate":
                self._open_crate_form(ctx["family"], ctx["weight"])
            elif ctx and ctx.get("type") == "troop":
                self._open_troop_form(ctx["name"])
            elif ctx and ctx.get("type") == "aircraft":
                self._open_aircraft_form(ctx["type_name"])
            elif ctx and ctx.get("type") == "zone_add":
                self._open_zone_add_form(ctx["zone_type"], ctx["idx"])
            elif ctx and ctx.get("type") == "vw":
                self._open_vehicle_weight_form(ctx["unit_name"])

    def _redo(self, event=None) -> None:  # noqa: ARG002
        if self.model.redo():
            ctx = self._current_context
            key = self._current_key
            self._rebuild_tree()
            self._refresh_status()
            if key:
                self._open_scalar_form(key)
            elif ctx and ctx.get("type") == "crate":
                self._open_crate_form(ctx["family"], ctx["weight"])
            elif ctx and ctx.get("type") == "troop":
                self._open_troop_form(ctx["name"])
            elif ctx and ctx.get("type") == "aircraft":
                self._open_aircraft_form(ctx["type_name"])
            elif ctx and ctx.get("type") == "zone_add":
                self._open_zone_add_form(ctx["zone_type"], ctx["idx"])
            elif ctx and ctx.get("type") == "vw":
                self._open_vehicle_weight_form(ctx["unit_name"])

    # --- status ------------------------------------------------------------------

    def _refresh_status(self) -> None:
        errors = [f for f in self.model.findings if f.severity == ERROR]
        warnings = [f for f in self.model.findings if f.severity != ERROR]
        if not self.model.findings:
            self._status_var.set(t("tui.validation.ok"))
        elif errors:
            self._status_var.set(t("tui.status.errors", n=len(errors)))
        else:
            self._status_var.set(t("tui.status.warnings", n=len(warnings)))
        state = tk.NORMAL if self.model.can_generate else tk.DISABLED
        self._gen_btn.configure(state=state)
        self._inject_btn.configure(state=state)

    # --- save / generate / inject ------------------------------------------------

    def _save(self) -> None:
        self.model.save(self._yaml_path)

    def _generate(self) -> None:
        if not self.model.can_generate:
            return
        self.model.generate(self._yaml_path.parent / self.USER_CONFIG_LUA)

    def _inject(self) -> None:
        if not self.model.can_generate:
            return
        from tkinter import filedialog

        miz = filedialog.askopenfilename(
            title=t("tui.prompt.inject"),
            filetypes=[("MIZ files", "*.miz"), ("All files", "*.*")],
            initialdir=str(self._yaml_path.parent),
        )
        if not miz:
            return
        from ctld_tools.miz import inject_userconfig

        inject_userconfig(miz, self.model.render(), miz)

    def run(self) -> None:
        self.root.mainloop()


def run(yaml_path: str | Path | None = None, src: str | Path | None = None) -> None:
    CtldToolsApp(yaml_path=yaml_path, src=src).run()
