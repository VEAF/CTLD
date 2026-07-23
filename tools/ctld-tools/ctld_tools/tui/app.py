"""The ctld-tools GUI — Mission Maker catalogue editor.

A navigable full-catalogue tree on the left; an editor form placeholder on the right.
The tree will show every CTLD parameter/table from the embedded Reference with 4 visual
states (default / modified* / added-green / deleted-strikethrough) — populated in later
tickets. The footer provides Save / Generate / Inject plus a live validation status.
Tooltips (via the Tooltip helper) will annotate field labels as the form is built out.
All strings go through the i18n layer. The `_test_mode` flag hides the window so the
tests can drive the app synchronously without a visible display.
"""

from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import ttk

import sv_ttk

from ctld_tools.editmodel import EditModel
from ctld_tools.i18n import t
from ctld_tools.reference import Reference
from ctld_tools.validate import ERROR


class CtldToolsApp:
    """Main application window — catalogue tree + editor form + footer."""

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
        if self._yaml_path.exists():
            self.model = EditModel.load(self._yaml_path, ref=ref)
        else:
            self.model = EditModel(ref=ref)

        self.root = tk.Tk()
        self.root.title(t("app.title"))
        self.root.minsize(900, 600)
        sv_ttk.set_theme("light")

        if _test_mode:
            self.root.withdraw()

        self._build_ui()
        self._refresh_status()

    # --- layout ------------------------------------------------------------------

    def _build_ui(self) -> None:
        # Main body: horizontal split — catalogue tree | editor form
        self._paned = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL, name="paned")
        self._paned.pack(fill=tk.BOTH, expand=True)

        # Left pane: catalogue tree with vertical scrollbar
        tree_frame = ttk.Frame(self._paned, name="tree_frame")
        self._tree = ttk.Treeview(
            tree_frame,
            show="tree",
            selectmode="browse",
            name="catalogue",
        )
        tree_scroll = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=self._tree.yview)
        self._tree.configure(yscrollcommand=tree_scroll.set)
        self._tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        tree_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self._paned.add(tree_frame, weight=1)

        # Right pane: editor form area (populated in later tickets)
        form_frame = ttk.Frame(self._paned, name="form_frame")
        self._paned.add(form_frame, weight=2)

        # Footer: status label (left) + action buttons (right) — always visible
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

    # --- status ------------------------------------------------------------------

    def _refresh_status(self) -> None:
        """Update the footer status label and Generate button state from model findings."""
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
        out = self._yaml_path.parent / self.USER_CONFIG_LUA
        self.model.generate(out)

    def _inject(self) -> None:
        if not self.model.can_generate:
            return
        # File picker implemented in a later ticket; placeholder for the wiring.

    def run(self) -> None:
        self.root.mainloop()


def run(yaml_path: str | Path | None = None, src: str | Path | None = None) -> None:
    CtldToolsApp(yaml_path=yaml_path, src=src).run()
