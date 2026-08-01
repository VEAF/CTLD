"""validate() reports the right findings for a complete catalogue + DCS types + schema."""

from ctld_tools.catalog import Catalog
from ctld_tools.i18n import language
from ctld_tools.schema import Schema
from ctld_tools.validate import ERROR, has_errors, validate

TYPES = frozenset({"Ural-375", "M-1 Abrams", "M 818"})
EMPTY = Schema({})

BASE = """\
mm_facing:
  spawnableCrates:
    Support:
    - unit: Ural-375
      desc: Ural Ammo
      weight: 1001.01
    SAM mid range:
    - unit: M 818
      desc: Launcher
      weight: 2001.01
    - desc: All crates
      side: 2
      mixedSet:
      - 2001.01
"""


def cat(text: str) -> Catalog:
    return Catalog.loads(text)


def test_valid_catalogue_has_no_errors():
    assert validate(cat(BASE), EMPTY, TYPES) == []


def test_unknown_unit_is_error():
    c = cat(BASE.replace("unit: Ural-375", "unit: NotAUnit"))
    findings = validate(c, EMPTY, TYPES)
    assert has_errors(findings)
    assert any(f.key == "validate.crate.unknown_unit" for f in findings)


def test_weight_collision_is_error():
    c = cat(BASE.replace("weight: 2001.01", "weight: 1001.01"))  # dup of the Support crate
    findings = validate(c, EMPTY, TYPES)
    assert any(f.key == "validate.crate.weight_collision" and f.severity == ERROR for f in findings)


def test_mixedset_dangling_weight_is_error():
    c = cat(BASE.replace("      - 2001.01", "      - 9999.99"))  # references a non-existent weight
    findings = validate(c, EMPTY, TYPES)
    assert any(f.key == "validate.mixedset.dangling_weight" for f in findings)


def test_mixedset_valid_reference_is_ok():
    assert validate(cat(BASE), EMPTY, TYPES) == []  # 2001.01 exists in its section


def test_bad_choice_is_error():
    schema = Schema({"JTAC_lock": {"choices": ["all", "vehicle", "troop"]}})
    c = cat("mm_facing:\n  JTAC_lock: sideways\n")
    findings = validate(c, schema, TYPES)
    assert any(f.key == "validate.setting.bad_choice" for f in findings)


def test_good_choice_is_ok():
    schema = Schema({"JTAC_lock": {"choices": ["all", "vehicle", "troop"]}})
    c = cat("mm_facing:\n  JTAC_lock: all\n")
    assert validate(c, schema, TYPES) == []


def test_finding_message_is_translated():
    c = cat(BASE.replace("unit: Ural-375", "unit: NotAUnit"))
    finding = next(f for f in validate(c, EMPTY, TYPES) if f.key == "validate.crate.unknown_unit")
    with language("en"):
        assert finding.message == "unknown DCS unit type 'NotAUnit'"
    with language("fr"):
        assert finding.message == "type d'unité DCS inconnu « NotAUnit »"


def test_validates_the_real_catalogue_clean():
    from pathlib import Path

    src = Path(__file__).resolve().parents[3] / "src"
    c = Catalog.load(src / "CTLD_config.yaml")
    s = Schema.load(src / "CTLD_config_schema.yaml")
    # the shipped catalogue must be internally consistent (mixedSets resolve, weights unique)
    errors = [f for f in validate(c, s) if f.severity == ERROR and f.key == "validate.mixedset.dangling_weight"]
    assert errors == []


# ── Type lists: a name that matches no DCS type can never match a mission object ────


def test_known_type_in_a_type_list_is_ok():
    assert validate(cat("mm_facing:\n  logisticUnitTypes:\n  - Ural-375\n"), EMPTY, TYPES) == []


def test_unknown_type_in_a_type_list_is_an_error():
    findings = validate(cat("mm_facing:\n  logisticUnitTypes:\n  - Stennnis\n"), EMPTY, TYPES)
    unknown = [f for f in findings if f.key == "validate.type_list.unknown_type"]
    assert len(unknown) == 1
    assert unknown[0].severity == ERROR
    assert unknown[0].params == {"name": "logisticUnitTypes", "type": "Stennnis"}
    assert has_errors(findings), "a type nothing can ever match must not export"


def test_a_modded_type_is_accepted_when_declared_in_modtypes():
    c = cat("mm_facing:\n  logisticUnitTypes:\n  - SuperCarrierMod\nadvanced:\n  modTypes:\n  - SuperCarrierMod\n")
    assert [f for f in validate(c, EMPTY, TYPES) if f.key == "validate.type_list.unknown_type"] == []


def test_an_empty_type_list_reports_nothing():
    assert validate(cat("mm_facing:\n  logisticUnitTypes: []\n"), EMPTY, TYPES) == []


def test_type_list_message_is_translated_in_both_languages():
    c = cat("mm_facing:\n  logisticUnitTypes:\n  - Stennnis\n")
    seen = {}
    for lang in ("en", "fr"):
        with language(lang):
            seen[lang] = next(f.message for f in validate(c, EMPTY, TYPES) if f.key == "validate.type_list.unknown_type")
    assert "Stennnis" in seen["en"] and "Stennnis" in seen["fr"]
    assert seen["en"] != seen["fr"], "the FR string must not fall back to EN"


# ── Completeness: parameters must all be present, lists may be removed ──────────────
# ADR 0011 Addendum 1. Keyed off the reference catalogue, never the schema.

REFERENCE = """\
mm_facing:
  slingLoad: false
  hoverTime: 10
  slingCutDestroyHeight: 40
  aiZones: []
  logisticUnits:
  - depot
advanced:
  maxDropHeight: 7.5
"""


def test_completeness_is_skipped_without_a_reference():
    """validate() stays a pure function: no reference, no completeness findings."""
    assert validate(cat("mm_facing:\n  slingLoad: false\n"), EMPTY, TYPES) == []


def test_complete_catalogue_has_no_completeness_error():
    findings = validate(cat(REFERENCE), EMPTY, TYPES, default=cat(REFERENCE))
    assert [f for f in findings if f.key == "validate.parameter.missing"] == []


def test_missing_parameter_is_an_error():
    incomplete = cat(REFERENCE.replace("  slingCutDestroyHeight: 40\n", ""))
    findings = validate(incomplete, EMPTY, TYPES, default=cat(REFERENCE))
    missing = [f for f in findings if f.key == "validate.parameter.missing"]
    assert len(missing) == 1
    assert missing[0].severity == ERROR
    assert missing[0].params["name"] == "slingCutDestroyHeight"
    assert has_errors(findings), "an incomplete config must not export"


def test_missing_parameter_in_the_advanced_section_is_an_error():
    incomplete = cat(REFERENCE.replace("  maxDropHeight: 7.5\n", ""))
    findings = validate(incomplete, EMPTY, TYPES, default=cat(REFERENCE))
    assert [f.params["name"] for f in findings if f.key == "validate.parameter.missing"] == ["maxDropHeight"]


def test_removing_a_list_is_legitimate_not_an_error():
    """A list default is a removable element (ADR 0011 point 1), so omitting it is deliberate."""
    for removed in ("  aiZones: []\n", "  logisticUnits:\n  - depot\n"):
        incomplete = cat(REFERENCE.replace(removed, ""))
        findings = validate(incomplete, EMPTY, TYPES, default=cat(REFERENCE))
        assert [f for f in findings if f.key == "validate.parameter.missing"] == [], removed


def test_several_missing_parameters_are_reported_individually():
    incomplete = cat(REFERENCE.replace("  slingLoad: false\n", "").replace("  hoverTime: 10\n", ""))
    findings = validate(incomplete, EMPTY, TYPES, default=cat(REFERENCE))
    names = sorted(f.params["name"] for f in findings if f.key == "validate.parameter.missing")
    assert names == ["hoverTime", "slingLoad"]


def test_missing_parameter_message_is_translated_in_both_languages():
    incomplete = cat(REFERENCE.replace("  hoverTime: 10\n", ""))
    seen = {}
    for lang in ("en", "fr"):
        with language(lang):
            findings = validate(incomplete, EMPTY, TYPES, default=cat(REFERENCE))
            seen[lang] = next(f.message for f in findings if f.key == "validate.parameter.missing")
    assert "hoverTime" in seen["en"] and "hoverTime" in seen["fr"]
    assert seen["en"] != seen["fr"], "the FR string must not fall back to EN"
