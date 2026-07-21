"""Double-click bridge: a command-less invocation in a terminal routes to the TUI."""

from ctld_tools.cli import _bridge_target


def test_no_command_in_tty_routes_to_tui():
    assert _bridge_target([], is_tty=True) == ["tui"]


def test_carries_global_options():
    assert _bridge_target(["--lang", "fr"], is_tty=True) == ["tui", "--lang", "fr"]


def test_explicit_command_runs_as_is():
    assert _bridge_target(["validate", "--yaml", "x"], is_tty=True) is None


def test_help_is_left_alone():
    assert _bridge_target(["--help"], is_tty=True) is None
    assert _bridge_target(["-h"], is_tty=True) is None


def test_non_tty_never_bridges():
    assert _bridge_target([], is_tty=False) is None  # pipes, CI, redirects
