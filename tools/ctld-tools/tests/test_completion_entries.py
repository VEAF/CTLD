"""complete() adds the fields a list entry lacks, only when the configuration predates the catalogue."""

from ctld_tools.catalog import Catalog
from ctld_tools.completion import complete

DEFAULT = """\
configVersion: "2.1.0"
mm_facing:
  numberOfTroops: 10
advanced:
  capabilitiesByType:
    Mi-8MT:
      maxCratesOnboard: 3
      crateSpawnSector: side
      crateSpawnDistance: 4.0
      loadableVehiclesBLUE:
      - Hummer
    UH-1H:
      maxCratesOnboard: 1
      crateSpawnSector: side
      crateSpawnDistance: 3.0
  spawnableCratesModels:
    load:
      shape: ammo_cargo
      size: 1.31
"""

#: A configuration written before the crate spawn fields existed.
STALE = """\
configVersion: "2.0.0"
mm_facing:
  numberOfTroops: 10
advanced:
  capabilitiesByType:
    Mi-8MT:
      maxCratesOnboard: 3
    UH-1H:
      maxCratesOnboard: 1
  spawnableCratesModels:
    load:
      shape: ammo_cargo
"""


def cat(text: str) -> Catalog:
    return Catalog.loads(text)


def entry(user: Catalog, container: str, name: str) -> dict:
    return dict(user.get(container)[name])


def test_an_older_configuration_gains_the_fields_of_the_entries_it_has():
    user = cat(STALE)
    complete(user, cat(DEFAULT))
    assert entry(user, "capabilitiesByType", "Mi-8MT")["crateSpawnSector"] == "side"
    assert entry(user, "capabilitiesByType", "Mi-8MT")["crateSpawnDistance"] == 4.0
    assert entry(user, "capabilitiesByType", "UH-1H")["crateSpawnDistance"] == 3.0


def test_a_crate_model_gains_its_size():
    user = cat(STALE)
    complete(user, cat(DEFAULT))
    assert entry(user, "spawnableCratesModels", "load")["size"] == 1.31


def test_each_addition_names_its_container_entry_and_field():
    user = cat(STALE)
    added = {(a.container, a.entry, a.key): a for a in complete(user, cat(DEFAULT))}
    sector = added[("capabilitiesByType", "Mi-8MT", "crateSpawnSector")]
    assert sector.value == "side"
    assert ("spawnableCratesModels", "load", "size") in added


def test_an_entry_the_catalogue_does_not_know_is_untouched():
    user = cat(STALE.replace("    UH-1H:\n      maxCratesOnboard: 1\n", "    MyOwnHeli:\n      maxCratesOnboard: 2\n"))
    complete(user, cat(DEFAULT))
    assert entry(user, "capabilitiesByType", "MyOwnHeli") == {"maxCratesOnboard": 2}


def test_an_entry_the_configuration_removed_is_not_recreated():
    user = cat(STALE.replace("    UH-1H:\n      maxCratesOnboard: 1\n", ""))
    complete(user, cat(DEFAULT))
    assert "UH-1H" not in user.get("capabilitiesByType")


def test_a_list_the_configuration_removed_is_not_recreated():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\n')
    complete(user, cat(DEFAULT))
    assert not user.has("capabilitiesByType")
    assert not user.has("spawnableCratesModels")


def test_a_current_configuration_keeps_a_field_it_lacks():
    user = cat(STALE.replace("2.0.0", "2.1.0"))
    added = complete(user, cat(DEFAULT))
    assert added == []
    assert "crateSpawnSector" not in entry(user, "capabilitiesByType", "Mi-8MT")


def test_a_newer_configuration_is_not_completed():
    user = cat(STALE.replace("2.0.0", "3.0.0"))
    assert complete(user, cat(DEFAULT)) == []


def test_a_configuration_with_no_version_counts_as_older():
    user = cat(STALE.replace('configVersion: "2.0.0"\n', ""))
    complete(user, cat(DEFAULT))
    assert entry(user, "capabilitiesByType", "Mi-8MT")["crateSpawnSector"] == "side"


def test_a_value_already_in_an_entry_is_kept():
    user = cat(
        STALE.replace("      maxCratesOnboard: 3\n", "      maxCratesOnboard: 3\n      crateSpawnDistance: 9.0\n", 1)
    )
    complete(user, cat(DEFAULT))
    assert entry(user, "capabilitiesByType", "Mi-8MT")["crateSpawnDistance"] == 9.0
    assert entry(user, "capabilitiesByType", "Mi-8MT")["crateSpawnSector"] == "side"


def test_a_list_field_of_an_entry_is_not_added():
    user = cat(STALE)
    complete(user, cat(DEFAULT))
    assert "loadableVehiclesBLUE" not in entry(user, "capabilitiesByType", "Mi-8MT")


def test_completing_twice_adds_nothing_the_second_time():
    user = cat(STALE)
    assert complete(user, cat(DEFAULT))
    assert complete(user, cat(DEFAULT)) == []
