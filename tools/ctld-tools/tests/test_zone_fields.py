"""Round-trip tests for positional ↔ named zone field conversion."""

import pytest

from ctld_tools.reference import _ZONE_FIELD_SCHEMAS, Reference, dict_to_zone, zone_to_dict


@pytest.fixture(scope="module")
def ref():
    return Reference.from_embedded()


def test_troop_zone_round_trip():
    fields = _ZONE_FIELD_SCHEMAS["troopZones"]
    positional = ["pickzone1", "blue", -1, "yes", 0]
    named = zone_to_dict(fields, positional)
    assert named["zoneName"] == "pickzone1"
    assert named["colour"] == "blue"
    assert named["troopLimit"] == -1
    assert named["canPickup"] == "yes"
    assert named["groupSize"] == 0
    back = dict_to_zone(fields, named)
    assert back[:5] == positional


def test_troop_zone_with_icon_id():
    fields = _ZONE_FIELD_SCHEMAS["troopZones"]
    positional = ["USA Carrier", "blue", 10, "yes", 0, 1001]
    named = zone_to_dict(fields, positional)
    assert named.get("iconId") == 1001
    back = dict_to_zone(fields, named)
    assert back == positional


def test_wp_zone_round_trip():
    fields = _ZONE_FIELD_SCHEMAS["wpZones"]
    positional = ["wpzone1", "green", "yes", 2]
    named = zone_to_dict(fields, positional)
    assert named["zoneName"] == "wpzone1"
    assert named["side"] == 2
    back = dict_to_zone(fields, named)
    assert back == positional


def test_ai_zone_round_trip():
    fields = _ZONE_FIELD_SCHEMAS["AIZones"]
    positional = ["aizone1", "supply", 0]
    named = zone_to_dict(fields, positional)
    assert named["zoneName"] == "aizone1"
    assert named["mode"] == "supply"
    back = dict_to_zone(fields, named)
    assert back == positional
