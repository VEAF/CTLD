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
