"""version_gap() diffs an authored catalogue against the current default catalogue."""

from ctld_tools.catalog import Catalog
from ctld_tools.versiongap import version_gap

USER = """\
configVersion: "2.0.0"
mm_facing:
  numberOfTroops: 10
advanced:
  hoverTime: 10
  legacyKnob: 5
"""

# Same shape at a newer version: hoverTime default changed, aaRearmDistance added,
# legacyKnob removed. numberOfTroops unchanged. configVersion differs (the discriminator).
CURRENT = """\
configVersion: "2.1.0"
mm_facing:
  numberOfTroops: 10
advanced:
  hoverTime: 15
  aaRearmDistance: 300
"""


def cat(text: str) -> Catalog:
    return Catalog.loads(text)


def test_same_version_is_empty_gap():
    same = CURRENT
    gap = version_gap(cat(same), cat(same))
    assert gap.is_empty
    assert gap.added == [] and gap.removed == [] and gap.changed == []


def test_versions_are_reported():
    gap = version_gap(cat(USER), cat(CURRENT))
    assert gap.from_version == "2.0.0"
    assert gap.to_version == "2.1.0"


def test_added_keys_surfaced():
    gap = version_gap(cat(USER), cat(CURRENT))
    assert gap.added == ["aaRearmDistance"]


def test_removed_keys_surfaced():
    gap = version_gap(cat(USER), cat(CURRENT))
    assert gap.removed == ["legacyKnob"]


def test_value_changed_keys_surfaced():
    gap = version_gap(cat(USER), cat(CURRENT))
    assert [c.key for c in gap.changed] == ["hoverTime"]
    (change,) = gap.changed
    assert change.old == 10
    assert change.new == 15


def test_unchanged_key_is_not_a_change():
    gap = version_gap(cat(USER), cat(CURRENT))
    assert "numberOfTroops" not in [c.key for c in gap.changed]


def test_config_version_excluded_from_diff():
    # configVersion always differs across versions; it is the discriminator, not a default.
    gap = version_gap(cat(USER), cat(CURRENT))
    assert "configVersion" not in gap.added
    assert "configVersion" not in gap.removed
    assert "configVersion" not in [c.key for c in gap.changed]


def test_gap_across_data_structures():
    # A data structure whose default changed surfaces as a single changed key.
    old = """\
configVersion: "2.0.0"
mm_facing:
  spawnableCrates:
    Support:
    - unit: Ural-375
      weight: 1001.01
"""
    new = """\
configVersion: "2.1.0"
mm_facing:
  spawnableCrates:
    Support:
    - unit: Ural-375
      weight: 1001.01
    - unit: M 818
      weight: 1001.02
"""
    gap = version_gap(cat(old), cat(new))
    assert [c.key for c in gap.changed] == ["spawnableCrates"]
