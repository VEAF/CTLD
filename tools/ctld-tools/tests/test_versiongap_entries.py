"""version_gap() also compares the fields of list entries, not only the flat top-level keys."""

from ctld_tools.catalog import Catalog
from ctld_tools.versiongap import version_gap

CURRENT = """\
configVersion: "2.1.0"
advanced:
  capabilitiesByType:
    Mi-8MT:
      maxCratesOnboard: 3
      crateSpawnSector: side
      crateSpawnDistance: 4.0
  spawnableCratesModels:
    load:
      shape: ammo_cargo
      size: 1.31
"""

USER = """\
configVersion: "2.0.0"
advanced:
  capabilitiesByType:
    Mi-8MT:
      maxCratesOnboard: 3
      crateSpawnDistance: 9.0
    MyOwnHeli:
      maxCratesOnboard: 2
  spawnableCratesModels:
    load:
      shape: ammo_cargo
"""


def gap():
    return version_gap(Catalog.loads(USER), Catalog.loads(CURRENT))


def test_a_field_the_entry_lacks_is_reported_as_added():
    added = {(f.container, f.entry, f.field): f.value for f in gap().added_fields}
    assert added[("capabilitiesByType", "Mi-8MT", "crateSpawnSector")] == "side"
    assert added[("spawnableCratesModels", "load", "size")] == 1.31


def test_a_field_the_entry_has_is_not_added():
    added = {(f.container, f.entry, f.field) for f in gap().added_fields}
    assert ("capabilitiesByType", "Mi-8MT", "crateSpawnDistance") not in added


def test_a_differing_default_of_a_present_field_is_reported_as_changed():
    changed = {(c.container, c.entry, c.field): (c.old, c.new) for c in gap().changed_fields}
    assert changed == {("capabilitiesByType", "Mi-8MT", "crateSpawnDistance"): (9.0, 4.0)}


def test_an_entry_the_catalogue_does_not_know_is_ignored():
    assert all(f.entry != "MyOwnHeli" for f in gap().added_fields)


def test_equal_versions_report_no_entry_fields():
    g = version_gap(Catalog.loads(CURRENT), Catalog.loads(CURRENT))
    assert g.added_fields == [] and g.changed_fields == []
    assert g.is_empty


def test_entry_fields_alone_make_the_gap_non_empty():
    assert not gap().is_empty
