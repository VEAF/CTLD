"""The reference resolves crate/troop names against the default catalogue."""

from pathlib import Path

import pytest

from ctld_tools.reference import Reference

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"


@pytest.fixture(scope="module")
def ref() -> Reference:
    return Reference.from_src(SRC)


def test_resolves_crate_by_name(ref):
    weight, err = ref.resolve_crate("Heavy Tank - Abrams")
    assert err is None
    assert weight == 1000.05


def test_resolves_aa_crate_by_name(ref):
    # AA crates are injected, not in the YAML — must still resolve.
    weight, err = ref.resolve_crate("HAWK Launcher")
    assert err is None and weight is not None


def test_resolves_crate_by_weight(ref):
    weight, err = ref.resolve_crate(1000.05)
    assert err is None and weight == 1000.05


def test_unknown_crate_name_gives_suggestion(ref):
    weight, err = ref.resolve_crate("Heavy Tank Abrams")  # missing dash
    assert weight is None
    assert "no crate named" in err
    assert "did you mean" in err


def test_troop_and_array_lookups(ref):
    assert ref.troop_exists("Standard Group")
    assert not ref.troop_exists("No Such Group")
    assert ref.is_array_setting("transportPilotNames")
    assert not ref.is_array_setting("numberOfTroops")
