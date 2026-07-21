"""Reusable textual widgets for the TUI.

`FilterablePicker` is the filter-as-you-type picker used everywhere a list is too long
to scroll — the crate `unit` (DCS types), the remove/patch crate picker, the troop
pickers, and the settings picker. An Input drives an OptionList; picking an option posts
a `Picked` message (carrying the option's *value*) to the parent.

Options may be plain strings, or `(value, label, search)` triples so the displayed label
(e.g. "name — description") differs from the returned value and from the searchable text.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Input, OptionList
from textual.widgets.option_list import Option

from ctld_tools.tui.filter import matches


class FilterablePicker(Vertical):
    """An Input + OptionList that narrows live and posts the picked value."""

    class Picked(Message):
        """Posted when the user selects an option."""

        def __init__(self, picker: FilterablePicker, value: str) -> None:
            self.picker = picker
            self.value = value
            super().__init__()

    def __init__(self, options, placeholder: str = "Type to filter…", id: str | None = None) -> None:
        super().__init__(id=id)
        self._items = [self._item(option) for option in options]  # (value, label, search)
        self._placeholder = placeholder

    @staticmethod
    def _item(option) -> tuple[str, str, str]:
        if isinstance(option, str):
            return option, option, option
        value, label, search = option
        return str(value), str(label), str(search)

    def compose(self) -> ComposeResult:
        yield Input(placeholder=self._placeholder)
        yield OptionList(*[Option(label, id=value) for value, label, _ in self._items])

    def _render_options(self, query: str) -> None:
        option_list = self.query_one(OptionList)
        option_list.clear_options()
        option_list.add_options(
            [Option(label, id=value) for value, label, search in self._items if matches(search, query)]
        )

    def on_input_changed(self, event: Input.Changed) -> None:
        event.stop()
        self._render_options(event.value)

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        event.stop()
        value = event.option.id if event.option.id is not None else str(event.option.prompt)
        self.post_message(self.Picked(self, value))
