"""validate() reports the right findings against the reference + DCS types."""

from pathlib import Path

import pytest

from ctld_tools.i18n import language
from ctld_tools.reference import Reference
from ctld_tools.validate import ERROR, WARNING, has_errors, validate

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"

# A tiny DCS type set is enough for unit-name checks.
TYPES = frozenset({"Ural-375", "M-1 Abrams"})


@pytest.fixture(scope="module")
def ref() -> Reference:
    return Reference.from_src(SRC)


def test_valid_config_has_no_errors(ref):
    cfg = {
        "crates": {
            "add": [{"section": "Support", "name": "Ural Ammo", "unit": "Ural-375", "weight_kg": 2000}],
            "remove": ["Heavy Tank - Abrams"],
            "patch": [{"name": "Humvee - TOW", "cratesRequired": 3}],
        },
        "troops": {"add": [{"name": "Recon", "inf": 3}], "remove": ["5x - Mortar Squad"]},
        "arrays": {"transportPilotNames": ["heli_x"]},
    }
    assert validate(cfg, ref, TYPES) == []


def test_unknown_unit_type_is_error(ref):
    cfg = {"crates": {"add": [{"name": "X", "unit": "NotARealUnit", "weight_kg": 9001}]}}
    findings = validate(cfg, ref, TYPES)
    assert has_errors(findings)
    assert any(f.key == "validate.crate.unknown_unit" for f in findings)


def test_weight_collision_is_error(ref):
    cfg = {"crates": {"add": [{"name": "X", "unit": "Ural-375", "weight_kg": 1000.05}]}}  # Abrams weight
    findings = validate(cfg, ref, TYPES)
    assert any(f.key == "validate.crate.weight_collision" and f.severity == ERROR for f in findings)


def test_two_new_crates_same_weight_collide(ref):
    cfg = {
        "crates": {
            "add": [
                {"name": "A", "unit": "Ural-375", "weight_kg": 424242},
                {"name": "B", "unit": "Ural-375", "weight_kg": 424242},  # same weight → collision
            ]
        }
    }
    findings = validate(cfg, ref, TYPES)
    assert any(f.key == "validate.crate.weight_collision" for f in findings)


def test_patch_to_existing_weight_collides(ref):
    # Patch a crate's weight onto another catalogue crate's weight → collision.
    cfg = {"crates": {"patch": [{"name": "Humvee - TOW", "weight_kg": 1000.05}]}}  # Abrams weight
    findings = validate(cfg, ref, TYPES)
    assert any(f.key == "validate.crate.weight_collision" for f in findings)


def test_patch_keeping_same_weight_is_ok(ref):
    # Patching other fields (or re-stating the crate's own weight) is not a collision.
    cfg = {"crates": {"patch": [{"name": "Humvee - TOW", "cratesRequired": 3}]}}
    assert validate(cfg, ref, TYPES) == []


def test_remove_unknown_crate_name_suggests(ref):
    cfg = {"crates": {"remove": ["Heavy Tank Abrams"]}}  # missing dash
    findings = validate(cfg, ref, TYPES)
    assert any(f.key == "validate.crate.unknown_hint" and f.params.get("suggestion") for f in findings)


def test_remove_unknown_troop_and_bad_array(ref):
    cfg = {"troops": {"remove": ["Nope Squad"]}, "arrays": {"notAnArray": [1]}}
    findings = validate(cfg, ref, TYPES)
    assert any(f.key in ("validate.troop.unknown", "validate.troop.unknown_hint") for f in findings)
    assert any(f.key == "validate.array.not_appendable" for f in findings)


def test_unknown_setting_is_warning_not_error(ref):
    findings = validate({"settings": {"noSuchSetting": 1}}, ref, TYPES)
    assert any(f.key.startswith("validate.setting.unknown") and f.severity == WARNING for f in findings)
    assert not has_errors(findings)  # a warning does not block generation


def test_known_setting_has_no_finding(ref):
    assert validate({"settings": {"numberOfTroops": 8}}, ref, TYPES) == []


def test_finding_message_is_translated(ref):
    cfg = {"crates": {"add": [{"name": "X", "unit": "NotARealUnit", "weight_kg": 9001}]}}
    finding = next(f for f in validate(cfg, ref, TYPES) if f.key == "validate.crate.unknown_unit")
    with language("en"):
        assert finding.message == "unknown DCS unit type 'NotARealUnit'"
    with language("fr"):
        assert finding.message == "type d'unité DCS inconnu « NotARealUnit »"
