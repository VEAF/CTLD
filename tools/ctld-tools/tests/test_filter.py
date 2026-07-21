"""The picker filter narrows a list by case-insensitive substring."""

from ctld_tools.tui.filter import filter_options


def test_empty_query_returns_all():
    assert filter_options(["Abrams", "Ural-375"], "") == ["Abrams", "Ural-375"]


def test_whitespace_query_returns_all():
    assert filter_options(["Abrams", "Ural-375"], "   ") == ["Abrams", "Ural-375"]


def test_case_insensitive_substring():
    assert filter_options(["Heavy Tank - Abrams", "Ural-375"], "abr") == ["Heavy Tank - Abrams"]


def test_matches_substring_anywhere():
    assert filter_options(["M-1 Abrams", "Ural-375"], "375") == ["Ural-375"]


def test_no_match_is_empty():
    assert filter_options(["Abrams", "Ural-375"], "zzz") == []


def test_order_is_preserved():
    assert filter_options(["b_tank", "a_tank", "tank_c"], "tank") == ["b_tank", "a_tank", "tank_c"]
