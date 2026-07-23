"""The ctld-tools GUI — Mission Maker catalogue editor.

Full catalogue tree on the left (all CTLD scalars with 4 visual states).
Selecting a scalar opens its editor form in the right pane. Footer: Save /
Generate / Inject + live validation status. Ctrl+Z/Y undo/redo.
"""

from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import ttk

import sv_ttk

from ctld_tools.editmodel import EditModel
from ctld_tools.i18n import current_language, t
from ctld_tools.reference import Reference
from ctld_tools.tui.forms import ScalarForm
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
        self._current_form: ScalarForm | None = None

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

        # Restore selection
        if prev_iid and self._tree.exists(prev_iid):
            self._tree.selection_set(prev_iid)
            self._tree.see(prev_iid)

    def _on_tree_select(self, event=None) -> None:  # noqa: ARG002
        sel = self._tree.selection()
        if not sel:
            return
        iid = sel[0]
        if iid.startswith("scalar:"):
            self._open_scalar_form(iid[len("scalar:") :])
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

    # --- undo / redo -------------------------------------------------------------

    def _undo(self, event=None) -> None:  # noqa: ARG002
        if self.model.undo():
            prev_key = self._current_key
            self._rebuild_tree()
            self._refresh_status()
            if prev_key:
                self._open_scalar_form(prev_key)

    def _redo(self, event=None) -> None:  # noqa: ARG002
        if self.model.redo():
            prev_key = self._current_key
            self._rebuild_tree()
            self._refresh_status()
            if prev_key:
                self._open_scalar_form(prev_key)

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
