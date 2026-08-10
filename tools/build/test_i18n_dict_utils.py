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


def test_parse_dict_skips_stale_commented_entry():
    text = (
        '-- STALE: ctld.i18n["ko"]["Dead Key"] = "죽은 키"\n'
        'ctld.i18n["ko"]["Live Key"] = "살아있는 키"\n'
    )
    assert parse_dict(text) == {"Live Key": "살아있는 키"}


def test_parse_dict_skips_stale_entry_with_empty_value():
    text = '-- STALE: ctld.i18n["ko"]["Dead Key"] = ""\n'
    assert parse_dict(text) == {}


def test_parse_keep_en_skips_commented_block_entry():
    text = (
        'ctld.i18n["fr"].__keep_en = {\n'
        '  ["BTR-D"] = true,\n'
        '  -- ["Old Mod Name"] = true,\n'
        "}\n"
        'ctld.i18n["fr"]["Actions"] = "Actions"\n'
    )
    assert parse_keep_en(text) == {"BTR-D"}
