"""The shape of the catalogue is pinned per version: it cannot change without a version increment.

`complete()` decides whether a missing list-entry field is a removal or an omission from the version tag,
so the tag has to move whenever the catalogue gains (or loses) a key or a field. This is the guard.
"""

import json
from pathlib import Path

from typer.testing import CliRunner

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.cli import app as cli_app
from ctld_tools.shape import GUIDANCE, catalogue_shape, shape_diff

REPO = Path(__file__).resolve().parents[3]
SHAPES = REPO / "tests" / "ci" / "data" / "catalogue_shapes"

SMALL = """\
configVersion: "2.1.0"
mm_facing:
  numberOfTroops: 10
advanced:
  hoverTime: 10
  capabilitiesByType:
    Mi-8MT:
      maxCratesOnboard: 3
      loadableVehiclesBLUE:
      - Hummer
"""


def cat(text: str) -> Catalog:
    return Catalog.loads(text)


def test_the_shape_lists_the_keys_and_the_scalar_fields_of_entries():
    shape = catalogue_shape(cat(SMALL))
    assert shape["version"] == "2.1.0"
    assert shape["keys"] == ["capabilitiesByType", "hoverTime", "numberOfTroops"]
    assert shape["entryFields"] == ["capabilitiesByType/Mi-8MT/maxCratesOnboard"]


def test_no_difference_when_nothing_changed():
    assert shape_diff(catalogue_shape(cat(SMALL)), catalogue_shape(cat(SMALL))) == []


def test_a_new_key_is_reported():
    changed = cat(SMALL.replace("  hoverTime: 10\n", "  hoverTime: 10\n  brandNewSetting: 1\n"))
    assert any("brandNewSetting" in line for line in shape_diff(catalogue_shape(cat(SMALL)), catalogue_shape(changed)))


def test_a_removed_key_is_reported():
    changed = cat(SMALL.replace("  hoverTime: 10\n", ""))
    assert any("hoverTime" in line for line in shape_diff(catalogue_shape(cat(SMALL)), catalogue_shape(changed)))


def test_a_new_entry_field_is_reported():
    changed = cat(
        SMALL.replace("      maxCratesOnboard: 3\n", "      maxCratesOnboard: 3\n      crateSpawnSector: side\n")
    )
    diff = shape_diff(catalogue_shape(cat(SMALL)), catalogue_shape(changed))
    assert any("capabilitiesByType/Mi-8MT/crateSpawnSector" in line for line in diff)


def test_a_changed_value_is_not_a_change_of_shape():
    changed = cat(SMALL.replace("hoverTime: 10", "hoverTime: 99"))
    assert shape_diff(catalogue_shape(cat(SMALL)), catalogue_shape(changed)) == []


def test_the_guidance_says_what_to_do():
    assert "configVersion" in GUIDANCE and "catalogue_shapes" in GUIDANCE


def test_the_catalogue_matches_the_snapshot_of_its_version():
    """The guard. Fails when `src/CTLD_config.yaml` gained or lost a key or a list-entry field
    without `configVersion` moving (or without the new version's snapshot being added)."""
    current = catalogue_shape(Catalog.load(resources.default_catalog_path()))
    snapshot_file = SHAPES / f"{current['version']}.json"
    assert snapshot_file.is_file(), f"no snapshot for catalogue version {current['version']}. {GUIDANCE}"
    snapshot = json.loads(snapshot_file.read_text(encoding="utf-8"))
    diff = shape_diff(snapshot, current)
    assert not diff, "the catalogue changed without a version increment:\n  " + "\n  ".join(diff) + f"\n{GUIDANCE}"


def test_a_changed_copy_of_the_real_catalogue_trips_the_guard():
    """Proves the guard fails when it should: a deliberately changed copy of the real catalogue."""
    copy = Catalog.load(resources.default_catalog_path())
    copy.add_setting("aSettingNobodyDeclaredAVersionFor", 1)
    snapshot = json.loads((SHAPES / f"{copy.get('configVersion')}.json").read_text(encoding="utf-8"))
    diff = shape_diff(snapshot, catalogue_shape(copy))
    assert any("aSettingNobodyDeclaredAVersionFor" in line for line in diff)


def test_the_shape_command_writes_the_snapshot(tmp_path):
    out = tmp_path / "shape.json"
    result = CliRunner().invoke(cli_app, ["shape", "--yaml", str(resources.default_catalog_path()), "--out", str(out)])
    assert result.exit_code == 0, result.output
    assert json.loads(out.read_text(encoding="utf-8"))["version"] == str(
        Catalog.load(resources.default_catalog_path()).get("configVersion")
    )
