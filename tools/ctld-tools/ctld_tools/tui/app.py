"""The ctld-tools TUI — the Mission Maker console.

A structured editor over the EditModel: the current user-config is shown by section on
the left, live validation on the right. Three action buttons (Add / Remove / Patch)
each open a type chooser (only the valid object types for that action), then a guided
form; Save / Generate / Inject finish the job. A tree entry can be deleted (with
confirmation), and edits are undoable (Ctrl+Z / Ctrl+Y). Generation is refused while any
validation error remains. All strings go through the i18n layer, so the UI follows the
OS language (or `--lang`).
"""

from __future__ import annotations

import time
from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Footer, Header, Label, RichLog, Tree

from ctld_tools.datamine import known_dcs_types
from ctld_tools.editmodel import EditModel
from ctld_tools.i18n import t
from ctld_tools.reference import ARRAY_SETTINGS, Reference
from ctld_tools.tui.forms import (
    AddCrateForm,
    AddTroopForm,
    AppendArrayForm,
    ConfirmModal,
    FileBrowserModal,
    PickerModal,
    SetSettingForm,
    TypeChooser,
)
from ctld_tools.validate import ERROR


def _patch_diff(entry: dict, default: dict) -> dict:
    """A minimal patch: the target name plus only the fields that differ from the default."""
    patch = {"name": entry.get("name")}
    for key, value in entry.items():
        if key != "name" and default.get(key) != value:
            patch[key] = value
    return patch


class CtldToolsApp(App):
    """MM console for authoring a user-config and generating / injecting it."""

    TITLE = "ctld-tools"

    CSS = """
    #body { height: 1fr; }
    #config { width: 2fr; border: solid $primary; }
    #side { width: 1fr; }
    #findings { height: 1fr; border: solid $secondary; }
    #actions { height: auto; layout: grid; grid-size: 6 1; grid-gutter: 0 1; }
    #actions Button { width: 1fr; }
    .form { width: 70%; height: auto; padding: 1 2; background: $surface; border: thick $primary; }
    .form-title { text-style: bold; }
    .form-buttons { height: auto; }
    """

    BINDINGS = [
        ("e", "edit_entry", t("tui.bind.edit")),
        ("delete", "delete_entry", t("tui.bind.delete")),
        ("ctrl+z", "undo", t("tui.bind.undo")),
        ("ctrl+y", "redo", t("tui.bind.redo")),
        ("ctrl+c", "quit", t("tui.bind.quit")),
    ]

    #: canonical file names — the user-config always has this name, and the generated
    #: Lua MUST be named this way for CTLD to load it, so neither is prompted for.
    USER_CONFIG_NAME = "user-config.yaml"
    USER_CONFIG_LUA = "CTLD_userConfig.lua"

    def __init__(self, yaml_path: str | Path | None = None, src: str | Path | None = None) -> None:
        super().__init__()
        self.sub_title = t("app.description")
        # Always the same file: default to user-config.yaml in the working directory.
        self._yaml_path = Path(yaml_path) if yaml_path else Path(self.USER_CONFIG_NAME)
        self._saved_at: float | None = None
        ref = Reference.from_src(src) if src else Reference.from_embedded()
        # Load it if it already exists, so re-opening the tool continues the last config.
        if self._yaml_path.exists():
            self.model = EditModel.load(self._yaml_path, ref=ref)
        else:
            self.model = EditModel(ref=ref)

    # --- layout ------------------------------------------------------------------

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="body"):
            yield Tree(t("tui.tree.root"), id="config")
            with Vertical(id="side"):
                yield Label(t("tui.validation"))
                yield RichLog(id="findings", markup=True, highlight=False)
        with Container(id="actions"):
            yield Button(t("tui.btn.add"), id="add", variant="primary")
            yield Button(t("tui.btn.remove"), id="remove")
            yield Button(t("tui.btn.patch"), id="patch")
            yield Button(t("tui.btn.save"), id="save")
            yield Button(t("tui.btn.generate"), id="generate", variant="success")
            yield Button(t("tui.btn.inject"), id="inject")
        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#config", Tree).show_root = False
        self._refresh()

    # --- rendering ---------------------------------------------------------------

    def _refresh(self) -> None:
        self._rebuild_tree()
        self._rebuild_findings()
        self.query_one("#generate", Button).disabled = not self.model.can_generate

    def _rebuild_tree(self) -> None:
        tree = self.query_one("#config", Tree)
        tree.clear()
        cfg = self.model.config

        settings = cfg.get("settings") or {}
        node = tree.root.add(t("tui.type.setting"), expand=True)
        for key in sorted(settings):
            node.add_leaf(f"{key} = {settings[key]}", data=("settings", key))

        crates = cfg.get("crates") or {}
        node = tree.root.add(t("tui.type.crate"), expand=True)
        for i, entry in enumerate(crates.get("add") or []):
            node.add_leaf(f"+ {entry.get('name', '?')} ({entry.get('unit', '?')})", data=("crates", "add", i))
        for i, target in enumerate(crates.get("remove") or []):
            node.add_leaf(f"- {target}", data=("crates", "remove", i))
        for i, entry in enumerate(crates.get("patch") or []):
            node.add_leaf(f"~ {entry.get('name', entry.get('weight', '?'))}", data=("crates", "patch", i))

        troops = cfg.get("troops") or {}
        node = tree.root.add(t("tui.type.troop"), expand=True)
        for i, entry in enumerate(troops.get("add") or []):
            node.add_leaf(f"+ {entry.get('name', '?')}", data=("troops", "add", i))
        for i, target in enumerate(troops.get("remove") or []):
            node.add_leaf(f"- {target}", data=("troops", "remove", i))
        for i, entry in enumerate(troops.get("patch") or []):
            node.add_leaf(f"~ {entry.get('name', '?')}", data=("troops", "patch", i))

        arrays = cfg.get("arrays") or {}
        node = tree.root.add(t("tui.type.array"), expand=True)
        for setting, items in arrays.items():
            for i, item in enumerate(items):
                node.add_leaf(f"{setting} += {item}", data=("arrays", setting, i))

    def _rebuild_findings(self) -> None:
        log = self.query_one("#findings", RichLog)
        log.clear()
        if not self.model.findings:
            log.write(f"[green]{t('tui.validation.ok')}[/green]")
            return
        for finding in self.model.findings:
            colour = "red" if finding.severity == ERROR else "yellow"
            log.write(f"[{colour}]{finding}[/{colour}]")

    # --- actions -----------------------------------------------------------------

    def on_button_pressed(self, event: Button.Pressed) -> None:
        handlers = {
            "add": lambda: self._choose_type("add"),
            "remove": lambda: self._choose_type("remove"),
            "patch": lambda: self._choose_type("patch"),
            "save": self._save,
            "generate": self._generate,
            "inject": self._inject,
        }
        handler = handlers.get(event.button.id or "")
        if handler:
            handler()

    _TYPES_FOR = {
        "add": ("crate", "troop", "setting", "array"),
        "remove": ("crate", "troop"),
        "patch": ("crate", "troop"),
    }

    def _choose_type(self, action: str) -> None:
        choices = [(kind, t(f"tui.type.{kind}")) for kind in self._TYPES_FOR[action]]

        def on_type(kind: str | None) -> None:
            if kind:
                self._open_form(action, kind)

        self.push_screen(TypeChooser(t(f"tui.choose.{action}"), choices), on_type)

    def _open_form(self, action: str, kind: str) -> None:
        opener = getattr(self, f"_form_{action}_{kind}", None)
        if opener:
            opener()

    def _apply(self, method_name: str, transform=lambda r: (r,)):
        """Return a screen callback that applies a non-None result via model.<method>.

        Dedup-capable ops (remove/patch) return False when rejected (duplicate or empty);
        surface that as a notice instead of silently mutating (the safety net behind the
        picker greying).
        """

        def callback(result) -> None:
            if result is None or result is False:
                return
            outcome = getattr(self.model, method_name)(*transform(result))
            if outcome is False:
                self.notify(t("tui.notify.op_rejected"), severity="warning")
                return
            self._refresh()

        return callback

    # add
    def _form_add_crate(self) -> None:
        self.push_screen(AddCrateForm(sorted(known_dcs_types())), self._apply("add_crate"))

    def _form_add_troop(self) -> None:
        self.push_screen(AddTroopForm(), self._apply("add_troop"))

    def _form_add_setting(self) -> None:
        self.push_screen(
            SetSettingForm(self.model.ref.scalar_settings(), self.model.ref),
            self._apply("set_setting", lambda r: (r["key"], r["value"])),
        )

    def _form_add_array(self) -> None:
        self.push_screen(
            AppendArrayForm(list(ARRAY_SETTINGS)), self._apply("append_array", lambda r: (r["setting"], r["value"]))
        )

    # remove
    def _form_remove_crate(self) -> None:
        self.push_screen(
            PickerModal(
                t("tui.form.remove_crate"),
                self.model.ref.crate_names(),
                disabled=self.model.consumed_names("crates", "remove"),
            ),
            self._apply("remove_crate"),
        )

    def _form_remove_troop(self) -> None:
        self.push_screen(
            PickerModal(
                t("tui.form.remove_troop"),
                self.model.ref.troop_names(),
                disabled=self.model.consumed_names("troops", "remove"),
            ),
            self._apply("remove_troop"),
        )

    # patch — pick the catalogue target, then edit the full form pre-filled with its
    # current values (CTLD default as a per-field hint); only changed fields are written.
    def _form_patch_crate(self) -> None:
        self._patch_via_form("crate")

    def _form_patch_troop(self) -> None:
        self._patch_via_form("troop")

    def _patch_via_form(self, kind: str) -> None:
        troop = kind == "troop"
        names = self.model.ref.troop_names() if troop else self.model.ref.crate_names()
        used = self.model.consumed_names("troops" if troop else "crates", "patch")
        title = t("tui.form.patch_troop" if troop else "tui.form.patch_crate")

        def on_pick(name: str | None) -> None:
            if not name:
                return
            default = self.model.ref.troop_default(name) if troop else self.model.ref.crate_default(name)
            method = "patch_troop" if troop else "patch_crate"

            def on_submit(entry) -> None:
                if not entry:
                    return
                if getattr(self.model, method)(_patch_diff(entry, default)) is False:
                    self.notify(t("tui.notify.op_rejected"), severity="warning")
                    return
                self._refresh()

            self._open_modify_form(kind, initial=default, default=default, on_submit=on_submit)

        self.push_screen(PickerModal(title, names, disabled=used), on_pick)

    def _open_modify_form(self, kind: str, initial: dict, default: dict, on_submit) -> None:
        """Open the full Add form pre-filled with `initial`, name locked (it is the target)."""
        if kind == "troop":
            form = AddTroopForm(initial=initial, defaults=default, lock_name=True)
        else:
            form = AddCrateForm(sorted(known_dcs_types()), initial=initial, defaults=default, lock_name=True)
        self.push_screen(form, on_submit)

    # --- delete / undo / redo ----------------------------------------------------

    def action_edit_entry(self) -> None:
        node = self.query_one("#config", Tree).cursor_node
        if node is None or node.data is None:
            self.notify(t("tui.notify.nothing_selected"))
            return
        address = node.data
        entry = self.model.get_entry(address)
        if entry is None:
            return
        kind = address[0]
        sub = address[1] if len(address) > 2 else None

        def apply(result) -> None:
            if not result:
                return
            if kind == "settings":
                if result["key"] == address[1]:
                    self.model.update_entry(address, result["value"])
                else:  # re-picked a different setting → move it
                    self.model.delete_entry(address)
                    self.model.set_setting(result["key"], result["value"])
            elif kind == "arrays":
                if result["setting"] == address[1]:
                    self.model.update_entry(address, result["value"])
                else:
                    self.model.delete_entry(address)
                    self.model.append_array(result["setting"], result["value"])
            else:
                self.model.update_entry(address, result)
            self._refresh()

        def apply_patch(result) -> None:
            # Editing an existing patch line: re-diff against the default and either
            # rewrite the (minimal) patch, or drop the line entirely if nothing differs.
            if not result:
                return
            name = entry.get("name")
            default = self.model.ref.troop_default(name) if kind == "troops" else self.model.ref.crate_default(name)
            patch = _patch_diff(result, default)
            if len(patch) <= 1:  # only the target name → nothing to change
                self.model.delete_entry(address)
            else:
                self.model.update_entry(address, patch)
            self._refresh()

        def open_patch_edit() -> None:
            name = entry.get("name")
            default = self.model.ref.troop_default(name) if kind == "troops" else self.model.ref.crate_default(name)
            initial = {**default, **entry}  # current effective values (default ⊕ patch)
            self._open_modify_form("troop" if kind == "troops" else "crate", initial, default, apply_patch)

        crate_names = self.model.ref.crate_names
        troop_names = self.model.ref.troop_names
        if kind == "crates" and sub == "add":
            self.push_screen(AddCrateForm(sorted(known_dcs_types()), initial=entry), apply)
        elif kind == "crates" and sub == "patch":
            open_patch_edit()
        elif kind == "crates" and sub == "remove":
            self.push_screen(PickerModal(t("tui.form.remove_crate"), crate_names()), apply)
        elif kind == "troops" and sub == "add":
            self.push_screen(AddTroopForm(initial=entry), apply)
        elif kind == "troops" and sub == "patch":
            open_patch_edit()
        elif kind == "troops" and sub == "remove":
            self.push_screen(PickerModal(t("tui.form.remove_troop"), troop_names()), apply)
        elif kind == "settings":
            self.push_screen(
                SetSettingForm(self.model.ref.scalar_settings(), self.model.ref, initial=(address[1], entry)), apply
            )
        elif kind == "arrays":
            self.push_screen(AppendArrayForm(list(ARRAY_SETTINGS), initial=(address[1], entry)), apply)

    def action_delete_entry(self) -> None:
        node = self.query_one("#config", Tree).cursor_node
        if node is None or node.data is None:
            self.notify(t("tui.notify.nothing_selected"))
            return
        address = node.data
        label = str(node.label)

        def confirm(ok: bool | None) -> None:
            if ok:
                self.model.delete_entry(address)
                self._refresh()

        self.push_screen(ConfirmModal(t("tui.confirm.delete", what=label)), confirm)

    def _since_last_save(self) -> str:
        if self._saved_at is None:
            return t("tui.quit.never")
        delta = time.time() - self._saved_at
        if delta < 60:
            return t("tui.quit.ago_sec", n=int(delta))
        return t("tui.quit.ago_min", n=int(delta / 60))

    async def action_quit(self) -> None:
        if not self.model.dirty:
            self.exit()
            return

        def confirm(ok: bool | None) -> None:
            if ok:
                self.exit()

        self.push_screen(
            ConfirmModal(
                t("tui.confirm.quit_unsaved", since=self._since_last_save()),
                yes_label=t("tui.quit.confirm"),
                no_label=t("tui.btn.cancel"),
            ),
            confirm,
        )

    def action_undo(self) -> None:
        if self.model.undo():
            self._refresh()
        else:
            self.notify(t("tui.notify.nothing_undo"))

    def action_redo(self) -> None:
        if self.model.redo():
            self._refresh()
        else:
            self.notify(t("tui.notify.nothing_redo"))

    # --- save / generate / inject ------------------------------------------------

    def _save(self) -> None:
        # Always the same file — no prompt.
        self.model.save(self._yaml_path)
        self._saved_at = time.time()
        self.notify(t("tui.notify.saved", path=self._yaml_path))

    def _generate(self) -> None:
        if not self.model.can_generate:
            self.notify(t("tui.notify.fix_errors"), severity="error")
            return
        # Canonical name (CTLD requires it), next to the user-config — no prompt.
        out = self._yaml_path.parent / self.USER_CONFIG_LUA
        self.model.generate(out)
        self.notify(t("tui.notify.generated", path=out))

    def _inject(self) -> None:
        if not self.model.can_generate:
            self.notify(t("tui.notify.fix_errors"), severity="error")
            return

        def apply(miz: str | None) -> None:
            if not miz:
                return
            from ctld_tools.miz import inject_userconfig

            inject_userconfig(miz, self.model.render(), miz)
            self.notify(t("tui.notify.injected", path=miz))

        root = str(self._yaml_path.parent) or "."
        self.push_screen(FileBrowserModal(t("tui.prompt.inject"), root=root), apply)


def run(yaml_path: str | Path | None = None, src: str | Path | None = None) -> None:
    CtldToolsApp(yaml_path=yaml_path, src=src).run()
