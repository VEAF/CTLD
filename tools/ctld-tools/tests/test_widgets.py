"""The FilterablePicker widget filters live and posts the picked value."""

from textual.app import App, ComposeResult
from textual.widgets import Input, OptionList

from ctld_tools.tui.widgets import FilterablePicker

OPTIONS = ["Heavy Tank - Abrams", "Ural-375", "M-818", "HAWK Launcher"]


class _Host(App):
    def compose(self) -> ComposeResult:
        yield FilterablePicker(OPTIONS)


async def test_shows_all_options_initially():
    async with _Host().run_test() as pilot:
        assert pilot.app.query_one(OptionList).option_count == len(OPTIONS)


async def test_filters_live_as_user_types():
    async with _Host().run_test() as pilot:
        pilot.app.query_one(Input).value = "abr"
        await pilot.pause()
        option_list = pilot.app.query_one(OptionList)
        assert option_list.option_count == 1
        assert str(option_list.get_option_at_index(0).prompt) == "Heavy Tank - Abrams"


async def test_clearing_filter_restores_all():
    async with _Host().run_test() as pilot:
        input_widget = pilot.app.query_one(Input)
        input_widget.value = "abr"
        await pilot.pause()
        input_widget.value = ""
        await pilot.pause()
        assert pilot.app.query_one(OptionList).option_count == len(OPTIONS)


class _HostDisabled(App):
    def compose(self) -> ComposeResult:
        yield FilterablePicker(OPTIONS, disabled={"Ural-375"}, disabled_suffix=" (used)")


async def test_disabled_option_is_marked_and_unselectable():
    async with _HostDisabled().run_test() as pilot:
        option_list = pilot.app.query_one(OptionList)
        by_id = {
            option_list.get_option_at_index(i).id: option_list.get_option_at_index(i)
            for i in range(option_list.option_count)
        }
        used = by_id["Ural-375"]
        assert used.disabled is True
        assert str(used.prompt) == "Ural-375 (used)"
        assert by_id["M-818"].disabled is False


async def test_disabled_option_survives_filtering():
    async with _HostDisabled().run_test() as pilot:
        pilot.app.query_one(Input).value = "ural"
        await pilot.pause()
        option_list = pilot.app.query_one(OptionList)
        assert option_list.option_count == 1
        assert option_list.get_option_at_index(0).disabled is True


async def test_selecting_option_posts_picked():
    picked: list[str] = []

    class _Listener(_Host):
        def on_filterable_picker_picked(self, event: FilterablePicker.Picked) -> None:
            picked.append(event.value)

    async with _Listener().run_test() as pilot:
        option_list = pilot.app.query_one(OptionList)
        option_list.highlighted = 1  # Ural-375
        await pilot.pause()
        option_list.action_select()
        await pilot.pause()
        assert picked == ["Ural-375"]
