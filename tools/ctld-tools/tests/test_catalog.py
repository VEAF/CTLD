"""Unit tests for the complete-catalogue model (ctld_tools.catalog.Catalog)."""

from pathlib import Path

from ctld_tools.catalog import Catalog

SRC_YAML = Path(__file__).resolve().parents[3] / "src" / "CTLD_config.yaml"

SAMPLE = """\
configVersion: "2.0.0"
mm_facing:
  numberOfTroops: 10
  spawnableCrates:
    Support:
    - unit: M 818
      desc: M-818 Ammo Truck
      weight: 1001.02
advanced:
  hoverTime: 10
  debug: false
"""


def cat() -> Catalog:
    return Catalog.loads(SAMPLE)


def test_get_across_sections_and_top_level():
    c = cat()
    assert c.get("numberOfTroops") == 10          # mm_facing
    assert c.get("hoverTime") == 10               # advanced
    assert str(c.get("configVersion")) == "2.0.0"  # top-level
    assert c.get("nope") is None
    assert c.get("nope", 42) == 42


def test_has_and_keys():
    c = cat()
    assert c.has("numberOfTroops") and c.has("hoverTime") and c.has("configVersion")
    assert not c.has("missing")
    ks = c.keys()
    for k in ("numberOfTroops", "spawnableCrates", "hoverTime", "debug", "configVersion"):
        assert k in ks


def test_set_edits_in_place():
    c = cat()
    c.set("numberOfTroops", 25)
    c.set("debug", True)
    assert c.get("numberOfTroops") == 25
    assert c.get("debug") is True


def test_set_unknown_raises():
    c = cat()
    try:
        c.set("brandNew", 1)
        assert False, "expected KeyError"
    except KeyError:
        pass


def test_add_and_remove_setting():
    c = cat()
    c.add_setting("brandNew", 7)               # default section = advanced
    assert c.get("brandNew") == 7
    c.remove("brandNew")
    assert not c.has("brandNew")


def test_remove_makes_element_absent():
    c = cat()
    c.remove("hoverTime")
    assert not c.has("hoverTime")               # missing = intentional removal


def test_data_section_is_mutable():
    c = cat()
    crates = c.data("spawnableCrates")["Support"]
    crates.append({"unit": "Ural-375", "desc": "Ural Ammo", "weight": 2000.01})
    assert c.data("spawnableCrates")["Support"][-1]["weight"] == 2000.01


def test_round_trip_preserves_values():
    c = cat()
    c.set("numberOfTroops", 25)
    reloaded = Catalog.loads(c.dumps())
    assert reloaded.get("numberOfTroops") == 25
    assert str(reloaded.get("configVersion")) == "2.0.0"
    assert reloaded.get("spawnableCrates")["Support"][0]["unit"] == "M 818"


def test_loads_the_real_catalogue():
    c = Catalog.load(SRC_YAML)
    assert c.get("numberOfTroops") == 10
    assert str(c.get("configVersion")) == "2.0.0"
    assert "SAM mid range" in c.get("spawnableCrates")   # AA baked in (lot 1 t05)
    # full round-trip: dump then reload equals the same settings
    again = Catalog.loads(c.dumps())
    assert again.get("aaRearmDistance") == c.get("aaRearmDistance")
