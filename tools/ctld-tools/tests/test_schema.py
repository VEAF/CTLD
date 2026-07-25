"""Unit tests for the authoring-schema accessor and its coverage of the catalogue."""

from pathlib import Path

from ctld_tools.catalog import Catalog
from ctld_tools.schema import Schema

SRC = Path(__file__).resolve().parents[3] / "src"
SCHEMA_YAML = SRC / "CTLD_config_schema.yaml"
CONFIG_YAML = SRC / "CTLD_config.yaml"


def sch() -> Schema:
    return Schema.load(SCHEMA_YAML)


def test_metadata_accessors():
    s = sch()
    assert s.group("JTAC_lock") == "jtac"
    assert s.choices("JTAC_lock") == ["all", "vehicle", "troop"]
    assert s.description("JTAC_lock", "en")
    assert s.description("JTAC_lock", "fr")


def test_lot1_knobs_were_recovered():
    s = sch()
    assert s.group("aaRearmDistance") == "aa"
    assert s.group("jtacLaserCodeMin") == "jtac"
    assert s.group("fobCrateCollectionRadius") == "fob"
    assert s.has("configVersion")  # recovered, tool-managed (no family)
    assert s.group("configVersion") is None


def test_families_present():
    fams = sch().families()
    for expected in ("aa", "beacon", "jtac", "fob", "crates", "troops", "general"):
        assert expected in fams


def test_uncovered_setting_is_none_not_error():
    s = sch()
    # a setting with no schema entry returns neutral values (UI uses a generic editor)
    assert s.group("__no_such_setting__") is None
    assert s.choices("__no_such_setting__") is None
    assert s.standard("__no_such_setting__") is False


def test_every_schema_key_is_a_real_setting():
    """No orphan schema entries: each maps to a setting present in the catalogue."""
    s = sch()
    c = Catalog.load(CONFIG_YAML)
    real = set(c.keys())
    # i18n_lang is a bare CTLD_i18n global (not in the defaults catalogue); tableFields is
    # UI table-column metadata (lot 3), not a setting.
    special = {"i18n_lang", "tableFields"}
    orphans = [k for k in s.keys() if k not in real and k not in special]
    assert orphans == [], f"schema entries with no matching setting: {orphans}"
