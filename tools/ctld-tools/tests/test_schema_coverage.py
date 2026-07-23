"""Golden test: every (table, field) pair known to Reference has EN+FR descriptions."""

import pytest

from ctld_tools.reference import _ZONE_FIELD_SCHEMAS, Reference

_TABLES_AND_FIELDS = {
    "spawnableCrates": [
        "desc", "unit", "weight_kg", "cratesRequired", "side",
        "isJTAC", "spawnAs",
        "specificParams.alti", "specificParams.orbitRadiusNoLase",
        "specificParams.orbitRadiusOnLase", "specificParams.speed",
    ],
    "loadableGroups": ["name", "inf", "mg", "at", "aa", "mortar", "jtac"],
    "capabilitiesByType": [
        "cratesEnabled", "troopsEnabled", "canSlingload", "canParachuteDrop",
        "useNativeDcsCargoSystem", "canTransportWholeVehicle", "convertNativeLoadToCTLD",
        "maxCratesOnboard", "maxTroopsOnboard", "maxWholeVehiclesOnboard",
        "maxVehicleWeight", "loadableVehiclesBLUE", "loadableVehiclesRED",
    ],
    "troopZones": [f["name"] for f in _ZONE_FIELD_SCHEMAS["troopZones"]],
    "wpZones": [f["name"] for f in _ZONE_FIELD_SCHEMAS["wpZones"]],
    "AIZones": [f["name"] for f in _ZONE_FIELD_SCHEMAS["AIZones"]],
    "groundVehicleWeights": ["unit", "weight_kg"],
}


@pytest.fixture(scope="module")
def ref():
    return Reference.from_embedded()


@pytest.mark.parametrize("table,field", [
    (table, field)
    for table, fields in _TABLES_AND_FIELDS.items()
    for field in fields
])
def test_field_has_en_description(ref, table, field):
    desc = ref.field_description(table, field, "en")
    assert desc, f"Missing EN description for {table}.{field}"


@pytest.mark.parametrize("table,field", [
    (table, field)
    for table, fields in _TABLES_AND_FIELDS.items()
    for field in fields
])
def test_field_has_fr_description(ref, table, field):
    desc = ref.field_description(table, field, "fr")
    assert desc, f"Missing FR description for {table}.{field}"
