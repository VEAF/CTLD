"""Unit tests for the Lua render (genconfig)."""

from ctld_tools.genconfig import render


def test_wraps_desc_and_name_in_ctld_tr():
    lua = render(
        {
            "spawnableCrates": {"Support": [{"weight": 1.0, "desc": "Ammo", "unit": "Ural-375"}]},
            "loadableGroups": [{"name": "Squad", "inf": 3}],
        }
    )
    assert 'desc = ctld.tr("Ammo")' in lua
    assert 'name = ctld.tr("Squad")' in lua
    # non-i18n string fields are NOT wrapped
    assert 'unit = "Ural-375"' in lua


def test_number_and_bool_rendering():
    lua = render({"count": 10, "rate": 7.6, "flag": True, "off": False})
    assert "count = 10" in lua
    assert "rate = 7.6" in lua
    assert "flag = true" in lua
    assert "off = false" in lua


def test_deterministic_output():
    data = {"b": 1, "a": 2, "nested": {"z": 1, "y": 2}}
    assert render(data) == render(data)


def test_defines_config_defaults_table():
    lua = render({"x": 1})
    assert "ctld.__configDefaults = {" in lua
    assert lua.startswith("-- GENERATED")


def test_non_identifier_keys_use_bracket_form():
    lua = render({"spawnableCrates": {"SAM mid range": []}})
    assert '["SAM mid range"]' in lua
