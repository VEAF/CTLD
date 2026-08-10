"""Stub detection: which entries translate_i18n.py sends to Claude for translation."""

from translate_i18n import _collect_stubs, _is_stub


def test_empty_value_is_a_stub():
    assert _is_stub("", "Actions") is True


def test_value_identical_to_en_is_a_stub():
    assert _is_stub("Actions", "Actions") is True


def test_real_translation_is_not_a_stub():
    assert _is_stub("액션", "Actions") is False


def test_collect_stubs_finds_empty_entries():
    en_dict = {"Actions": "Actions", "Cut Slingload": "Cut Slingload"}
    lang_dict = {"Actions": "", "Cut Slingload": "잘라내기"}
    assert _collect_stubs(en_dict, lang_dict, keep_en=set()) == {"Actions": "Actions"}


def test_collect_stubs_finds_en_copies():
    en_dict = {"Actions": "Actions"}
    lang_dict = {"Actions": "Actions"}
    assert _collect_stubs(en_dict, lang_dict, keep_en=set()) == {"Actions": "Actions"}


def test_collect_stubs_excludes_keep_en_keys_even_when_empty():
    en_dict = {"Humvee - MG": "Humvee - MG"}
    lang_dict = {"Humvee - MG": ""}
    assert _collect_stubs(en_dict, lang_dict, keep_en={"Humvee - MG"}) == {}


def test_collect_stubs_skips_real_translations():
    en_dict = {"Actions": "Actions"}
    lang_dict = {"Actions": "액션"}
    assert _collect_stubs(en_dict, lang_dict, keep_en=set()) == {}
