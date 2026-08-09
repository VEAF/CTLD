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


def test_sound_settings_declare_their_editor():
    """The picker is bound to `editor: sound`, never to a setting name in a component."""
    s = sch()
    assert s.editor("radioSound") == "sound"
    assert s.editor("radioSoundFC3") == "sound"
    assert s.editor("hoverTime") is None
    assert s.editor("__no_such_setting__") is None


def test_original_name_labels_are_schema_only_and_hidden():
    """The original file name is a label: declared here, absent from the catalogue, never shown.

    Catalogued it would be a *parameter* under ADR 0011 Addendum 1, so the completeness rule would
    demand it of every snapshot and every pre-lot configuration would report a missing setting at
    mission start — FIX-TOOL-I18N-LANG's wall. And having no default is what lets "absent" mean
    "this sound is the bundled one".
    """
    s = sch()
    c = Catalog.load(CONFIG_YAML)
    for key in ("radioSoundOriginalName", "radioSoundFC3OriginalName"):
        assert s.has(key), f"{key} must be declared in the schema"
        assert s.hidden(key) is True, f"{key} is a label, not a setting the MM edits"
        assert not c.has(key), f"{key} must stay out of the default catalogue"
        assert s.default(key) is None, f"{key} must have no default"
    assert s.hidden("radioSound") is False


def test_every_schema_key_is_a_real_setting():
    """No orphan schema entries: each maps to a setting present in the catalogue."""
    s = sch()
    c = Catalog.load(CONFIG_YAML)
    real = set(c.keys())
    # i18n_lang is a bare CTLD_i18n global (not in the defaults catalogue); tableFields is
    # UI table-column metadata (lot 3), not a setting; the two *OriginalName keys are labels the
    # tool writes beside a custom beacon sound, deliberately uncatalogued (ADR 0012).
    special = {"i18n_lang", "tableFields", "radioSoundOriginalName", "radioSoundFC3OriginalName"}
    orphans = [k for k in s.keys() if k not in real and k not in special]
    assert orphans == [], f"schema entries with no matching setting: {orphans}"
