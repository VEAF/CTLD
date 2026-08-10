"""Parsing a CTLD_i18n_XX.lua dict file's content into keys/values and __keep_en set."""

from i18n_dict_utils import parse_dict, parse_keep_en


def test_parses_well_formed_entries():
    text = (
        'ctld.i18n["ko"]["Drop Crate(s)"] = "테스트"\n'
        'ctld.i18n["ko"]["Cut Slingload"] = ""\n'
    )
    assert parse_dict(text) == {
        "Drop Crate(s)": "테스트",
        "Cut Slingload": "",
    }


def test_excludes_translation_version():
    text = (
        'ctld.i18n["ko"].translation_version = "1.17"\n'
        'ctld.i18n["ko"]["Actions"] = "액션"\n'
    )
    assert "translation_version" not in parse_dict(text)


def test_handles_escaped_quotes_in_value():
    text = 'ctld.i18n["ko"]["Greeting"] = "Say \\"Hi\\""\n'
    assert parse_dict(text) == {"Greeting": 'Say \\"Hi\\"'}


def test_parse_keep_en_collects_block_keys_only():
    text = (
        'ctld.i18n["fr"].__keep_en = {\n'
        '  ["Humvee - MG"] = true,\n'
        '  ["BTR-D"] = true,\n'
        "}\n"
        'ctld.i18n["fr"]["Actions"] = "Actions"\n'
    )
    assert parse_keep_en(text) == {"Humvee - MG", "BTR-D"}


def test_parse_keep_en_empty_when_no_block():
    text = 'ctld.i18n["fr"]["Actions"] = "Actions"\n'
    assert parse_keep_en(text) == set()
