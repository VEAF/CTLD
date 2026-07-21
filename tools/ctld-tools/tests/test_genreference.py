"""The embedded reference bundle is generated from src/ and committed.

`gen-reference` (lupa, build-time) freezes the catalogue the runtime needs to resolve
and validate names — crates (AA injected), troop groups — into a JSON bundle. A golden
check keeps the committed bundle in sync with src/ (the drift guard).
"""

import json
from pathlib import Path

import pytest

from ctld_tools.genreference import BUNDLE_PATH, build_reference_bundle

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"


@pytest.fixture(scope="module")
def bundle() -> dict:
    return build_reference_bundle(SRC)


def test_bundle_has_crates_and_troops(bundle):
    assert bundle["spawnableCrates"]
    assert bundle["loadableGroups"]


def test_bundle_has_scalar_settings(bundle):
    assert bundle["scalarSettings"]["numberOfTroops"] == 10


def test_bundle_includes_injected_aa_crates(bundle):
    descs = {entry.get("desc") for section in bundle["spawnableCrates"].values() for entry in section}
    assert "HAWK Launcher" in descs  # AA crate — injected, not in the YAML


def test_committed_bundle_matches_src(bundle):
    """Golden: the committed reference.json equals a fresh regeneration from src/."""
    committed = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))
    assert committed == bundle


def test_write_reference_round_trips(tmp_path, bundle):
    from ctld_tools.genreference import write_reference

    out = tmp_path / "reference.json"
    write_reference(SRC, out)
    assert json.loads(out.read_text(encoding="utf-8")) == bundle
