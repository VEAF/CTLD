"""validate() reports the right findings against the reference + DCS types."""

from pathlib import Path

import pytest

from ctld_tools.reference import Reference
from ctld_tools.validate import ERROR, has_errors, validate

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
    assert any("unknown DCS unit" in f.message for f in findings)


def test_weight_collision_is_error(ref):
    cfg = {"crates": {"add": [{"name": "X", "unit": "Ural-375", "weight_kg": 1000.05}]}}  # Abrams weight
    findings = validate(cfg, ref, TYPES)
    assert any("collides" in f.message and f.severity == ERROR for f in findings)


def test_remove_unknown_crate_name_suggests(ref):
    cfg = {"crates": {"remove": ["Heavy Tank Abrams"]}}  # missing dash
    findings = validate(cfg, ref, TYPES)
    assert any("no crate named" in f.message and "did you mean" in f.message for f in findings)


def test_remove_unknown_troop_and_bad_array(ref):
    cfg = {"troops": {"remove": ["Nope Squad"]}, "arrays": {"notAnArray": [1]}}
    findings = validate(cfg, ref, TYPES)
    assert any("no troop group named" in f.message for f in findings)
    assert any("not an appendable array setting" in f.message for f in findings)
