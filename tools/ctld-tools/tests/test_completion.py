"""complete() adds the scalar parameters a configuration lacks, from the default catalogue."""

from ctld_tools.catalog import Catalog
from ctld_tools.completion import complete

DEFAULT = """\
configVersion: "2.0.0"
mm_facing:
  numberOfTroops: 10
  enableParachuteDrop: true
advanced:
  hoverTime: 10
  crateSpawnGap: 0.5
  capabilitiesByType:
    Mi-8MT:
      maxCratesOnboard: 3
  spawnableCratesModels:
    load:
      shape: ammo_cargo
"""


def cat(text: str) -> Catalog:
    return Catalog.loads(text)


def test_adds_a_missing_scalar_with_its_default():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n')
    added = complete(user, cat(DEFAULT))
    assert {a.key for a in added} == {"enableParachuteDrop", "crateSpawnGap"}
    assert user.get("crateSpawnGap") == 0.5
    assert user.get("enableParachuteDrop") is True


def test_the_scalar_lands_in_the_section_where_the_default_keeps_it():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n')
    complete(user, cat(DEFAULT))
    assert "enableParachuteDrop" in user._doc["mm_facing"]
    assert "crateSpawnGap" in user._doc["advanced"]


def test_a_section_the_configuration_lacks_is_created_for_its_scalar():
    user = cat('configVersion: "2.0.0"\nadvanced:\n  hoverTime: 10\n')
    complete(user, cat(DEFAULT))
    assert user._doc["mm_facing"]["numberOfTroops"] == 10


def test_a_present_value_is_kept_even_when_the_default_differs():
    user = cat(
        'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 4\n  enableParachuteDrop: false\nadvanced:\n  hoverTime: 99\n  crateSpawnGap: 2\n'
    )
    added = complete(user, cat(DEFAULT))
    assert added == []
    assert user.get("numberOfTroops") == 4
    assert user.get("enableParachuteDrop") is False
    assert user.get("hoverTime") == 99


def test_lists_and_maps_are_never_added():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n')
    complete(user, cat(DEFAULT))
    assert not user.has("capabilitiesByType")
    assert not user.has("spawnableCratesModels")


def test_a_list_entry_missing_a_field_is_left_alone():
    user = cat(
        'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n'
        "  capabilitiesByType:\n    Mi-8MT: {}\n"
    )
    complete(user, cat(DEFAULT))
    assert dict(user.get("capabilitiesByType")["Mi-8MT"]) == {}


def test_the_version_tag_is_not_a_completed_parameter():
    user = cat("mm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n")
    added = complete(user, cat(DEFAULT))
    assert "configVersion" not in {a.key for a in added}
    assert not user.has("configVersion")


def test_a_key_only_the_configuration_has_is_untouched():
    user = cat(
        'configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n  legacyKnob: 5\n'
    )
    complete(user, cat(DEFAULT))
    assert user.get("legacyKnob") == 5


def test_completing_twice_adds_nothing_the_second_time():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n')
    assert complete(user, cat(DEFAULT))
    assert complete(user, cat(DEFAULT)) == []


def test_an_addition_reports_its_key_value_and_section():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\nadvanced:\n  hoverTime: 10\n')
    by_key = {a.key: a for a in complete(user, cat(DEFAULT))}
    assert by_key["crateSpawnGap"].value == 0.5
    assert by_key["crateSpawnGap"].section == "advanced"
    assert by_key["enableParachuteDrop"].section == "mm_facing"


def test_stamp_version_writes_the_catalogue_version():
    user = cat('configVersion: "1.9.0"\nmm_facing:\n  numberOfTroops: 10\n')
    user.stamp_version("2.0.0")
    assert user.get("configVersion") == "2.0.0"


def test_stamp_version_creates_the_tag_when_missing():
    user = cat("mm_facing:\n  numberOfTroops: 10\n")
    user.stamp_version("2.0.0")
    assert user.get("configVersion") == "2.0.0"
    assert next(iter(user._doc)) == "configVersion"
