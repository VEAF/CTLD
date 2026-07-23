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


def test_i18n_lang_is_a_first_class_setting(ref):
    # FIX-I18N-LANG-SETTING: now in the catalogue, with a value list.
    assert ref.scalar_settings().get("i18n_lang") == "en"
    assert ref.enum_choices("i18n_lang") == ["en", "fr", "es", "ko"]


def test_setting_descriptions_are_bilingual(ref):
    assert "interface" in ref.setting_description("i18n_lang", "en").lower()
    assert "interface" in ref.setting_description("i18n_lang", "fr").lower()
    # Unknown lang falls back to EN; undocumented setting → None.
    assert ref.setting_description("i18n_lang", "zz") == ref.setting_description("i18n_lang", "en")
    assert ref.setting_description("no_such_setting") is None


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


@pytest.fixture(scope="module")
def embedded_ref() -> Reference:
    return Reference.from_embedded()


def test_aircraft_types_returns_sorted_list(embedded_ref):
    types = embedded_ref.aircraft_types()
    assert isinstance(types, list)
    assert "UH-1H" in types
    assert types == sorted(types)


def test_aircraft_capabilities_returns_dict(embedded_ref):
    caps = embedded_ref.aircraft_capabilities()
    assert "UH-1H" in caps
    assert isinstance(caps["UH-1H"], dict)
    assert caps["UH-1H"]["cratesEnabled"] is True


def test_zone_fields_troop_returns_list(embedded_ref):
    fields = embedded_ref.zone_fields("troopZones")
    assert len(fields) >= 5
    names = [f["name"] for f in fields]
    assert "zoneName" in names
    assert "colour" in names


def test_default_zones_troop(embedded_ref):
    zones = embedded_ref.default_zones("troopZones")
    assert len(zones) == 21
    assert zones[0][0] == "pickzone1"


def test_default_zones_wp(embedded_ref):
    zones = embedded_ref.default_zones("wpZones")
    assert len(zones) == 10


def test_default_zones_ai(embedded_ref):
    zones = embedded_ref.default_zones("AIZones")
    assert isinstance(zones, list)


def test_default_list_transport_pilots(embedded_ref):
    names = embedded_ref.default_list("transportPilotNames")
    assert len(names) == 108
    assert "helicargo1" in names
    assert "MEDEVAC #1" in names


def test_default_list_extract_groups(embedded_ref):
    names = embedded_ref.default_list("extractableGroups")
    assert len(names) == 25
    assert "extract1" in names


def test_vehicle_weights_returns_dict(embedded_ref):
    vw = embedded_ref.vehicle_weights()
    assert "BRDM-2" in vw
    assert vw["BRDM-2"] == 7000
