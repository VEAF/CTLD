"""Tests for the one-shot extractor (sectioning + Lua load)."""

from pathlib import Path

from ctld_tools.extract import sectionize
from ctld_tools.luaconfig import load_default_settings

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"


def test_load_default_settings_shape():
    s = load_default_settings(SRC)
    assert isinstance(s, dict)
    assert s["numberOfTroops"] == 10
    assert isinstance(s["spawnableCrates"], dict)
    assert isinstance(s["transportPilotNames"], list)
    # i18n key preserved verbatim under identity translator
    assert s["spawnableCrates"]["Combat Vehicles"][0]["desc"] == "Humvee - MG"


def test_sectionize_splits_and_preserves_all_keys():
    settings = load_default_settings(SRC)
    doc = sectionize(settings)
    assert set(doc.keys()) == {"mm_facing", "advanced"}
    merged = {**doc["mm_facing"], **doc["advanced"]}
    assert merged == settings
    # a few expected placements
    assert "spawnableCrates" in doc["mm_facing"]
    assert "SOLDIER_WEIGHT" in doc["advanced"]
