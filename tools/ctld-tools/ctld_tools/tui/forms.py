"""Modal forms for the TUI — one guided form per operation.

Each form is a ModalScreen that dismisses with a plain result the app hands to the
EditModel (a crate/troop entry dict, a picked name, a (key, value) pair), or None when
cancelled. Large lists use the FilterablePicker; scalars use labelled inputs. All
user-visible strings go through the i18n layer (`t`).
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import Button, DirectoryTree, Input, Label, Select

from ctld_tools.i18n import t
from ctld_tools.tui.widgets import FilterablePicker


def _blank(value) -> str:
    """Render a value for an input field: empty string when None."""
    return "" if value is None else str(value)


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


class _FormScreen(ModalScreen):
    """Common modal chrome: Escape cancels."""

    BINDINGS = [("escape", "cancel", "Cancel")]

    def action_cancel(self) -> None:
        self.dismiss(None)


class TypeChooser(_FormScreen):
    """Second step of an action: pick which kind of thing to add/remove/patch."""

    def __init__(self, title: str, choices: list[tuple[str, str]]) -> None:
        super().__init__()
        self._title = title
        self._choices = choices  # (value, label)

    def compose(self) -> ComposeResult:
        with Vertical(classes="form"):
            yield Label(self._title, classes="form-title")
            for value, label in self._choices:
                yield Button(label, id=f"type-{value}")
            yield Button(t("tui.btn.cancel"), id="cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        bid = event.button.id or ""
        self.dismiss(bid[len("type-") :] if bid.startswith("type-") else None)


class ConfirmModal(_FormScreen):
    """A yes/no confirmation; dismisses with a bool. Labels are overridable."""

    def __init__(self, message: str, yes_label: str | None = None, no_label: str | None = None) -> None:
        super().__init__()
        self._message = message
        self._yes_label = yes_label or t("tui.confirm.yes")
        self._no_label = no_label or t("tui.confirm.no")

    def compose(self) -> ComposeResult:
        with Vertical(classes="form"):
            yield Label(self._message, classes="form-title")
            with Horizontal(classes="form-buttons"):
                yield Button(self._yes_label, id="yes", variant="error")
                yield Button(self._no_label, id="no")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(event.button.id == "yes")

    def action_cancel(self) -> None:
        self.dismiss(False)


class PickerModal(_FormScreen):
    """Pick one value from a (large) list — remove crate, remove troop.

    `disabled` names (already consumed in the diff) render non-selectable, so a
    duplicate op is unreachable (error prevention).
    """

    def __init__(self, title: str, options, disabled=None) -> None:
        super().__init__()
        self._title = title
        self._options = list(options)
        self._disabled = set(disabled or [])

    def compose(self) -> ComposeResult:
        with Vertical(classes="form"):
            yield Label(self._title, classes="form-title")
            yield FilterablePicker(
                self._options,
                placeholder=t("tui.ph.filter"),
                id="picker",
                disabled=self._disabled,
                disabled_suffix=t("tui.picker.used_suffix"),
            )
            yield Button(t("tui.btn.cancel"), id="cancel")

    def on_filterable_picker_picked(self, event: FilterablePicker.Picked) -> None:
        self.dismiss(event.value)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(None)


class AddCrateForm(_FormScreen):
    """Add or edit a crate: labelled inputs + a filterable DCS-type picker for `unit`."""

    def __init__(self, unit_types, initial: dict | None = None) -> None:
        super().__init__()
        self._unit_types = list(unit_types)
        self._initial = dict(initial or {})
        self._unit: str | None = self._initial.get("unit")

    def compose(self) -> ComposeResult:
        init = self._initial
        with Vertical(classes="form"):
            yield Label(t("tui.form.add_crate"), classes="form-title")
            yield Input(value=str(init.get("section", "Support")), placeholder=t("tui.ph.section"), id="section")
            yield Input(value=_blank(init.get("name")), placeholder=t("tui.ph.name"), id="name")
            yield Input(
                value=_blank(init.get("weight_kg", init.get("weight"))), placeholder=t("tui.ph.weight"), id="weight"
            )
            yield Input(value=_blank(init.get("side")), placeholder=t("tui.ph.side"), id="side")
            yield Input(
                value=_blank(init.get("cratesRequired")), placeholder=t("tui.ph.crates_required"), id="crates_required"
            )
            unit_label = t("tui.label.unit", unit=self._unit) if self._unit else t("tui.label.unit_none")
            yield Label(unit_label, id="unit-label")
            yield FilterablePicker(self._unit_types, placeholder=t("tui.ph.unit_filter"), id="unit-picker")
            with Horizontal(classes="form-buttons"):
                yield Button(t("tui.btn.confirm"), id="submit", variant="primary")
                yield Button(t("tui.btn.cancel"), id="cancel")

    def on_filterable_picker_picked(self, event: FilterablePicker.Picked) -> None:
        self._unit = event.value
        self.query_one("#unit-label", Label).update(t("tui.label.unit", unit=event.value))

    _MANAGED = ("section", "name", "unit", "weight", "weight_kg", "side", "cratesRequired")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel":
            self.dismiss(None)
            return
        # Keep any extra fields the form does not expose (e.g. specificParams) when editing.
        entry: dict = {k: v for k, v in self._initial.items() if k not in self._MANAGED}
        for field in ("section", "name"):
            value = self.query_one(f"#{field}", Input).value.strip()
            if value:
                entry[field] = value
        if self._unit:
            entry["unit"] = self._unit
        weight = coerce(self.query_one("#weight", Input).value)
        if weight is not None:
            entry["weight_kg"] = weight
        side = coerce(self.query_one("#side", Input).value)
        if side is not None:
            entry["side"] = side
        crates_required = coerce(self.query_one("#crates_required", Input).value)
        if crates_required is not None:
            entry["cratesRequired"] = crates_required
        self.dismiss(entry)


class PatchByNameForm(_FormScreen):
    """Patch one field of a crate or troop group, targeted by name from a picker."""

    def __init__(self, title: str, names, initial: dict | None = None, disabled=None) -> None:
        super().__init__()
        self._title = title
        self._names = list(names)
        self._disabled = set(disabled or [])
        init = dict(initial or {})
        self._name: str | None = init.get("name")
        self._init_field = next((k for k in init if k != "name"), "")
        self._init_value = init.get(self._init_field) if self._init_field else None

    def compose(self) -> ComposeResult:
        target_label = t("tui.label.target", name=self._name) if self._name else t("tui.label.target_none")
        with Vertical(classes="form"):
            yield Label(self._title, classes="form-title")
            yield Label(target_label, id="target-label")
            yield FilterablePicker(
                self._names,
                placeholder=t("tui.ph.filter"),
                id="target-picker",
                disabled=self._disabled,
                disabled_suffix=t("tui.picker.used_suffix"),
            )
            yield Input(value=self._init_field, placeholder=t("tui.ph.field"), id="field")
            yield Input(value=_blank(self._init_value), placeholder=t("tui.ph.value"), id="value")
            with Horizontal(classes="form-buttons"):
                yield Button(t("tui.btn.confirm"), id="submit", variant="primary")
                yield Button(t("tui.btn.cancel"), id="cancel")

    def on_filterable_picker_picked(self, event: FilterablePicker.Picked) -> None:
        self._name = event.value
        self.query_one("#target-label", Label).update(t("tui.label.target", name=event.value))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel" or not self._name:
            self.dismiss(None)
            return
        field = self.query_one("#field", Input).value.strip()
        if not field:
            self.dismiss(None)
            return
        self.dismiss({"name": self._name, field: coerce(self.query_one("#value", Input).value)})


class AddTroopForm(_FormScreen):
    """Add or edit a troop group: a name plus optional per-type counts."""

    COUNT_FIELDS = ("inf", "mg", "at", "aa", "mortar", "jtac")

    def __init__(self, initial: dict | None = None) -> None:
        super().__init__()
        self._initial = dict(initial or {})

    def compose(self) -> ComposeResult:
        init = self._initial
        with Vertical(classes="form"):
            yield Label(t("tui.form.add_troop"), classes="form-title")
            yield Input(value=_blank(init.get("name")), placeholder=t("tui.ph.name"), id="name")
            for field in self.COUNT_FIELDS:
                yield Input(value=_blank(init.get(field)), placeholder=t("tui.ph.count", field=field), id=field)
            with Horizontal(classes="form-buttons"):
                yield Button(t("tui.btn.confirm"), id="submit", variant="primary")
                yield Button(t("tui.btn.cancel"), id="cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel":
            self.dismiss(None)
            return
        # Preserve any extra fields not exposed as count inputs.
        managed = {"name", *self.COUNT_FIELDS}
        name = self.query_one("#name", Input).value.strip()
        entry: dict = {k: v for k, v in self._initial.items() if k not in managed}
        if name:
            entry["name"] = name
        for field in self.COUNT_FIELDS:
            value = coerce(self.query_one(f"#{field}", Input).value)
            if value is not None:
                entry[field] = value
        self.dismiss(entry)


class SetSettingForm(_FormScreen):
    """Set one scalar setting: pick it, then edit the value with the right widget.

    Booleans and enum settings (from the schema) offer a Select (choose from a list);
    everything else is a free text input pre-filled with the default.
    """

    def __init__(self, settings: dict, ref, initial: tuple | None = None) -> None:
        super().__init__()
        self._settings = dict(settings)
        self._ref = ref
        self._initial = initial  # (key, current_value) when editing, else None
        self._key: str | None = None
        self._value_kind = "input"  # "input" | "bool" | "enum"

    def _options(self):
        """(value, label, search) per setting — label/search include the description."""
        from ctld_tools.i18n import current_language

        lang = current_language()
        items = []
        for name in sorted(self._settings):
            desc = self._ref.setting_description(name, lang)
            label = f"{name} — {desc}" if desc else name
            search = f"{name} {desc}" if desc else name
            items.append((name, label, search))
        return items

    def compose(self) -> ComposeResult:
        with Vertical(classes="form"):
            yield Label(t("tui.form.set_setting"), classes="form-title")
            yield Label(t("tui.label.setting_none"), id="setting-label")
            yield FilterablePicker(self._options(), placeholder=t("tui.ph.setting_filter"), id="setting-picker")
            yield Vertical(id="value-slot")
            with Horizontal(classes="form-buttons"):
                yield Button(t("tui.btn.confirm"), id="submit", variant="primary")
                yield Button(t("tui.btn.cancel"), id="cancel")

    async def on_mount(self) -> None:
        # Editing an existing setting: pre-select it and show its current value.
        if self._initial:
            key, current = self._initial
            await self._show_value(key, current)

    async def on_filterable_picker_picked(self, event: FilterablePicker.Picked) -> None:
        await self._show_value(event.value, self._settings.get(event.value))

    async def _show_value(self, key: str, value) -> None:
        self._key = key
        default = self._settings.get(key)
        # Highlight the default value in bold in the label (Rich markup).
        self.query_one("#setting-label", Label).update(
            t("tui.label.setting_default", name=key, default=f"[b]{default}[/b]")
        )
        slot = self.query_one("#value-slot", Vertical)
        await slot.remove_children()
        choices = self._ref.enum_choices(key)
        marker = t("tui.default_marker")

        def _label(option: str, is_default: bool) -> str:
            return f"{option}  ({marker})" if is_default else option  # mark the default option

        if isinstance(default, bool):
            self._value_kind = "bool"
            options = [(_label("true", default is True), "true"), (_label("false", default is False), "false")]
            await slot.mount(Select(options, value=str(value).lower(), allow_blank=False, id="value-select"))
        elif choices:
            self._value_kind = "enum"
            options = [(_label(c, c == str(default)), c) for c in choices]
            await slot.mount(Select(options, value=str(value), allow_blank=False, id="value-select"))
        else:
            self._value_kind = "input"
            await slot.mount(Input(value=str(value), placeholder=t("tui.ph.value"), id="value"))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel" or not self._key:
            self.dismiss(None)
            return
        if self._value_kind == "bool":
            value: object = self.query_one("#value-select", Select).value == "true"
        elif self._value_kind == "enum":
            value = self.query_one("#value-select", Select).value
        else:
            value = coerce(self.query_one("#value", Input).value)
        self.dismiss({"key": self._key, "value": value})


class AppendArrayForm(_FormScreen):
    """Append one entry to an array setting (picked from the known array names)."""

    def __init__(self, array_settings, initial: tuple | None = None) -> None:
        super().__init__()
        self._array_settings = list(array_settings)
        self._initial = initial  # (setting, current_value) when editing, else None
        self._setting: str | None = initial[0] if initial else None

    def compose(self) -> ComposeResult:
        setting_label = t("tui.label.setting", setting=self._setting) if self._setting else t("tui.label.setting_none")
        with Vertical(classes="form"):
            yield Label(t("tui.form.append_array"), classes="form-title")
            yield Label(setting_label, id="setting-label")
            yield FilterablePicker(self._array_settings, placeholder=t("tui.ph.filter"), id="setting-picker")
            yield Input(
                value=_blank(self._initial[1]) if self._initial else "", placeholder=t("tui.ph.value"), id="value"
            )
            with Horizontal(classes="form-buttons"):
                yield Button(t("tui.btn.confirm"), id="submit", variant="primary")
                yield Button(t("tui.btn.cancel"), id="cancel")

    def on_filterable_picker_picked(self, event: FilterablePicker.Picked) -> None:
        self._setting = event.value
        self.query_one("#setting-label", Label).update(t("tui.label.setting", setting=event.value))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel" or not self._setting:
            self.dismiss(None)
            return
        self.dismiss({"setting": self._setting, "value": coerce(self.query_one("#value", Input).value)})


class _MizDirectoryTree(DirectoryTree):
    """A DirectoryTree that shows only directories and .miz files."""

    def filter_paths(self, paths):
        return [p for p in paths if p.is_dir() or p.suffix.lower() == ".miz"]


class FileBrowserModal(_FormScreen):
    """Browse the filesystem and pick a .miz file; dismisses with its path (or None)."""

    def __init__(self, title: str, root: str = ".") -> None:
        super().__init__()
        self._title = title
        self._root = root

    def compose(self) -> ComposeResult:
        with Vertical(classes="form"):
            yield Label(self._title, classes="form-title")
            yield _MizDirectoryTree(self._root, id="filetree")
            yield Button(t("tui.btn.cancel"), id="cancel")

    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        self.dismiss(str(event.path))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss(None)
