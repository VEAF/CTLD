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
from ctld_tools.reference import Reference
from ctld_tools.tui.forms import AircraftForm, CrateForm, ScalarForm, TroopForm
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
        self._current_form: ScalarForm | CrateForm | TroopForm | AircraftForm | None = None
        self._current_context: dict | None = None

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

    # --- tree --------------------------------------------------------------------

    def _rebuild_tree(self) -> None:
        selected = self._tree.selection()
        prev_iid = selected[0] if selected else None

        self._tree.delete(*self._tree.get_children())
        overrides = self.model.config.get("settings", {})
        scalars = self.model.ref.scalar_settings()

        params = self._tree.insert("", "end", iid="params", text=t("tui.section.parameters"), open=True)
        std_node = self._tree.insert(params, "end", iid="params_standard", text=t("tui.section.standard"), open=False)
        adv_node = self._tree.insert(params, "end", iid="params_advanced", text=t("tui.section.advanced"), open=False)

        for key in sorted(scalars):
            parent = std_node if self.model.ref.is_mm_facing(key) else adv_node
            is_modified = key in overrides
            effective = overrides[key] if is_modified else scalars[key]
            label = f"{key} = {effective}{'  *' if is_modified else ''}"
            tag = "modified" if is_modified else "default"
            self._tree.insert(parent, "end", iid=f"scalar:{key}", text=label, tags=(tag,))

        # --- Crates section ---
        self._rebuild_crates_section()

        # --- Troops section ---
        self._rebuild_troops_section()

        # --- Aircraft section ---
        self._rebuild_aircraft_section()

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
        else:
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
