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
    assert err.key == "validate.crate.unknown_hint"
    assert err.params["suggestion"]


def test_troop_and_array_lookups(ref):
    assert ref.troop_exists("Standard Group")
    assert not ref.troop_exists("No Such Group")
    assert ref.is_array_setting("transportPilotNames")
    assert not ref.is_array_setting("numberOfTroops")


def test_scalar_settings_resolve(ref):
    settings = ref.scalar_settings()
    assert settings["numberOfTroops"] == 10
    assert ref.setting_exists("slingLoad")
    assert not ref.setting_exists("noSuchSetting")
    assert ref.closest_setting("numberOftroop") == "numberOfTroops"


def test_enum_choices_from_schema(ref):
    assert ref.enum_choices("JTAC_lock") == ["all", "vehicle", "troop"]
    assert ref.enum_choices("numberOfTroops") is None


def test_from_embedded_resolves_identically_to_from_src(ref):
    """The committed bundle (from_embedded) resolves the same as from_src."""
    embedded = Reference.from_embedded()
    assert embedded.crate_weights() == ref.crate_weights()
    # A stock crate, an AA (injected) crate, a troop group, an array setting.
    assert embedded.resolve_crate("Heavy Tank - Abrams") == ref.resolve_crate("Heavy Tank - Abrams")
    assert embedded.resolve_crate("HAWK Launcher") == ref.resolve_crate("HAWK Launcher")
    assert embedded.troop_exists("Standard Group")
    assert embedded.is_array_setting("troopZones")
    assert embedded.scalar_settings() == ref.scalar_settings()
    assert embedded.enum_choices("JTAC_lock") == ref.enum_choices("JTAC_lock")
