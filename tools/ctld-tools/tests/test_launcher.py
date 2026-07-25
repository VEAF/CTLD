"""The double-click launcher routing + parent-process-tree detection."""

from ctld_tools.web.launcher import is_double_clicked, resolve_action


def test_bare_invocation_serves():
    assert resolve_action([]) == "serve"


def test_global_option_only_still_serves():
    assert resolve_action(["--lang", "fr"]) == "serve"
    assert resolve_action(["--lang=fr"]) == "serve"


def test_explicit_command_runs_cli():
    assert resolve_action(["validate", "--yaml", "x"]) == "cli"
    assert resolve_action(["embed"]) == "cli"
    assert resolve_action(["serve"]) == "cli"  # explicit serve goes through Typer


def test_help_goes_to_cli():
    assert resolve_action(["--help"]) == "cli"
    assert resolve_action(["-h"]) == "cli"


def test_double_click_detected_from_explorer():
    assert is_double_clicked(["explorer.exe"]) is True


def test_conhost_is_skipped():
    assert is_double_clicked(["conhost.exe", "explorer.exe"]) is True


def test_shell_ancestor_is_not_double_click():
    assert is_double_clicked(["cmd.exe"]) is False
    assert is_double_clicked(["pwsh.exe", "explorer.exe"]) is False  # shell wins (nearer)
    assert is_double_clicked(["bash"]) is False


def test_no_ancestors_is_not_double_click():
    assert is_double_clicked([]) is False
