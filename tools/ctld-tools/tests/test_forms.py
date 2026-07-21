"""The form input coercion turns raw text into the right scalar type."""

from ctld_tools.tui.forms import coerce


def test_blank_is_none():
    assert coerce("") is None
    assert coerce("   ") is None


def test_booleans():
    assert coerce("true") is True
    assert coerce("False") is False


def test_int_and_float():
    assert coerce("8") == 8
    assert isinstance(coerce("8"), int)
    assert coerce("2000.5") == 2000.5


def test_string_fallback():
    assert coerce("Ural-375") == "Ural-375"
    assert coerce("  padded  ") == "padded"
