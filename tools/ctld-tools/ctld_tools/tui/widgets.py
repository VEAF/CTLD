"""Reusable textual widgets for the TUI.

`FilterablePicker` is the filter-as-you-type picker used everywhere a list is too long
to scroll — the crate `unit` (DCS types), the remove/patch crate picker, the troop
pickers. It is a thin view over the pure `filter_options`: an Input drives an OptionList,
and picking an option posts a `Picked` message to the parent.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.message import Message
from textual.widgets import Input, OptionList
from textual.widgets.option_list import Option

from ctld_tools.tui.filter import filter_options


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
        self._options = [str(option) for option in options]
        self._placeholder = placeholder

    def compose(self) -> ComposeResult:
        yield Input(placeholder=self._placeholder)
        yield OptionList(*[Option(option) for option in self._options])

    def _render_options(self, narrowed: list[str]) -> None:
        option_list = self.query_one(OptionList)
        option_list.clear_options()
        option_list.add_options([Option(option) for option in narrowed])

    def on_input_changed(self, event: Input.Changed) -> None:
        event.stop()
        self._render_options(filter_options(self._options, event.value))

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        event.stop()
        self.post_message(self.Picked(self, str(event.option.prompt)))
