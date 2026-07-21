"""The user-config edit model — state + operations + live validation, no UI.

Holds the parsed user-config and exposes the operations the MM performs (add/remove/
patch a crate, add/remove a troop group, set a scalar setting, append an array entry).
Every operation re-runs the existing validation against the reference (embedded by
default) and the DCS type set; generation is allowed only when no error-severity
finding remains. The textual TUI is a thin view/controller over this model, so all the
logic is unit-testable without widgets.
"""

from __future__ import annotations

import copy
from pathlib import Path

from ctld_tools.reference import Reference
from ctld_tools.validate import Finding, has_errors, load_user_config, validate


class EditModel:
    def __init__(self, config: dict | None = None, ref: Reference | None = None, types=None):
        self.config: dict = config or {}
        self.ref: Reference = ref or Reference.from_embedded()
        self._types = types
        self.findings: list[Finding] = []
        self._undo: list[dict] = []
        self._redo: list[dict] = []
        self.dirty = False  # unsaved changes since the last save/load
        self.revalidate()

    # --- undo / redo -------------------------------------------------------------

    def _checkpoint(self) -> None:
        """Snapshot the state before a mutation; a new edit clears the redo stack."""
        self._undo.append(copy.deepcopy(self.config))
        self._redo.clear()
        self.dirty = True

    @property
    def can_undo(self) -> bool:
        return bool(self._undo)

    @property
    def can_redo(self) -> bool:
        return bool(self._redo)

    def undo(self) -> bool:
        if not self._undo:
            return False
        self._redo.append(copy.deepcopy(self.config))
        self.config = self._undo.pop()
        self.dirty = True
        self.revalidate()
        return True

    def redo(self) -> bool:
        if not self._redo:
            return False
        self._undo.append(copy.deepcopy(self.config))
        self.config = self._redo.pop()
        self.dirty = True
        self.revalidate()
        return True

    # --- validation --------------------------------------------------------------

    def revalidate(self) -> list[Finding]:
        """Recompute findings from the current state (called after every operation)."""
        self.findings = validate(self.config, self.ref, self._types)
        return self.findings

    @property
    def can_generate(self) -> bool:
        """True when nothing blocks generation (no error-severity finding)."""
        return not has_errors(self.findings)

    # --- operations --------------------------------------------------------------

    def _crates(self, key: str) -> list:
        return self.config.setdefault("crates", {}).setdefault(key, [])

    def _troops(self, key: str) -> list:
        return self.config.setdefault("troops", {}).setdefault(key, [])

    def add_crate(self, entry: dict) -> None:
        self._checkpoint()
        self._crates("add").append(dict(entry))
        self.revalidate()

    def remove_crate(self, target) -> None:
        self._checkpoint()
        self._crates("remove").append(target)
        self.revalidate()

    def patch_crate(self, entry: dict) -> None:
        self._checkpoint()
        self._crates("patch").append(dict(entry))
        self.revalidate()

    def add_troop(self, entry: dict) -> None:
        self._checkpoint()
        self._troops("add").append(dict(entry))
        self.revalidate()

    def remove_troop(self, name) -> None:
        self._checkpoint()
        self._troops("remove").append(name)
        self.revalidate()

    def patch_troop(self, entry: dict) -> None:
        self._checkpoint()
        self._troops("patch").append(dict(entry))
        self.revalidate()

    def set_setting(self, key: str, value) -> None:
        self._checkpoint()
        self.config.setdefault("settings", {})[key] = value
        self.revalidate()

    def append_array(self, setting: str, item) -> None:
        self._checkpoint()
        self.config.setdefault("arrays", {}).setdefault(setting, []).append(item)
        self.revalidate()

    def delete_entry(self, address: tuple) -> None:
        """Delete one entry from the document, addressed as it appears in the tree.

        Address forms: ("settings", key), ("arrays", setting, idx), or
        (section, subsection, idx) for crates/troops (e.g. ("crates", "add", 0)).
        """
        self._checkpoint()
        kind = address[0]
        if kind == "settings":
            self.config.get("settings", {}).pop(address[1], None)
        elif kind == "arrays":
            _, setting, idx = address
            items = self.config.get("arrays", {}).get(setting)
            if items and 0 <= idx < len(items):
                items.pop(idx)
                if not items:
                    del self.config["arrays"][setting]
        else:
            _, sub, idx = address
            entries = self.config.get(kind, {}).get(sub)
            if entries and 0 <= idx < len(entries):
                entries.pop(idx)
        self.revalidate()

    def get_entry(self, address: tuple):
        """Return the current value at a tree address (for editing), or None."""
        kind = address[0]
        try:
            if kind == "settings":
                return self.config["settings"][address[1]]
            if kind == "arrays":
                return self.config["arrays"][address[1]][address[2]]
            return self.config[kind][address[1]][address[2]]
        except (KeyError, IndexError, TypeError):
            return None

    def update_entry(self, address: tuple, value) -> None:
        """Replace the entry at a tree address in place (same address forms as delete_entry)."""
        self._checkpoint()
        kind = address[0]
        if kind == "settings":
            self.config["settings"][address[1]] = value
        elif kind == "arrays":
            self.config["arrays"][address[1]][address[2]] = value
        else:
            self.config[kind][address[1]][address[2]] = value
        self.revalidate()

    # --- load / save / generate --------------------------------------------------

    @classmethod
    def load(cls, path: str | Path, ref: Reference | None = None, types=None) -> EditModel:
        return cls(load_user_config(path), ref=ref, types=types)

    def save(self, path: str | Path) -> None:
        """Clean-rewrite the state to YAML (no comment preservation)."""
        from ruamel.yaml import YAML

        yaml = YAML()
        yaml.default_flow_style = False
        with Path(path).open("w", encoding="utf-8", newline="\n") as fh:
            yaml.dump(self.config, fh)
        self.dirty = False

    def render(self) -> str:
        """Render CTLD_userConfig.lua (raises UserConfigError while errors remain)."""
        from ctld_tools.genuser import render_user_config

        return render_user_config(self.config, self.ref)

    def generate(self, out_path: str | Path) -> None:
        Path(out_path).write_text(self.render(), encoding="utf-8", newline="\n")
