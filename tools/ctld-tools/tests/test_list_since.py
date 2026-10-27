"""A list the catalogue gained after a configuration's version is not a removal (ADR 0011 Addendum 3).

The build writes `ctld.configListSince` from the pinned shapes; the engine and `complete()` read it, so a
mission configuration written before the Fat Cow gets its crates and loadouts instead of empty lists.
"""

from pathlib import Path

from typer.testing import CliRunner

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.cli import app as cli_app
from ctld_tools.completion import complete
from ctld_tools.since import list_since, load_shapes, to_lua

REPO = Path(__file__).resolve().parents[3]
SHAPES = REPO / "tests" / "ci" / "data" / "catalogue_shapes"

DEFAULT = """\
configVersion: "2.3.0"
mm_facing:
  numberOfTroops: 10
  aiZones: []
  fatCowCrates:
  - desc: tank
    fuelKg: 2400
"""

SHAPES_FIXTURE = [
    {"version": "2.1.0", "keys": ["numberOfTroops", "aiZones"], "entryFields": []},
    {"version": "2.3.0", "keys": ["numberOfTroops", "aiZones", "fatCowCrates"], "entryFields": []},
    {"version": "2.2.0", "keys": ["numberOfTroops", "aiZones"], "entryFields": []},
]


def cat(text: str) -> Catalog:
    return Catalog.loads(text)


def test_a_list_later_than_the_oldest_shape_is_dated():
    assert list_since(cat(DEFAULT), SHAPES_FIXTURE) == {"fatCowCrates": "2.3.0"}


def test_the_shipped_catalogue_dates_the_fat_cow_lists():
    since = list_since(Catalog.load(REPO / "src" / "CTLD_config.yaml"), load_shapes(SHAPES))
    for key in ("fatCowCrates", "fatCowLoadouts", "fatCowTypes"):
        assert since[key] == "2.3.0"
    assert "aiZones" not in since
    assert "fatCowEnabled" not in since  # a parameter, not a list


def test_the_lua_module_round_trips_through_the_engine_reader(tmp_path, monkeypatch):
    engine = tmp_path / "CTLD.lua"
    engine.write_text("ctld = {}\n" + to_lua({"fatCowCrates": "2.3.0", "fatCowTypes": "2.3.0"}), encoding="utf-8")
    monkeypatch.setattr(resources, "engine_path", lambda: engine)
    assert resources.list_since() == {"fatCowCrates": "2.3.0", "fatCowTypes": "2.3.0"}


def test_the_cli_writes_the_module(tmp_path):
    out = tmp_path / "since.lua"
    result = CliRunner().invoke(
        cli_app, ["since", "--yaml", str(REPO / "src" / "CTLD_config.yaml"), "--shapes", str(SHAPES), "--out", str(out)]
    )
    assert result.exit_code == 0, result.output
    assert '["fatCowLoadouts"] = "2.3.0",' in out.read_text(encoding="utf-8")


def test_complete_adds_a_list_newer_than_the_configuration():
    user = cat('configVersion: "2.2.0"\nmm_facing:\n  numberOfTroops: 10\n  aiZones: []\n')
    added = complete(user, cat(DEFAULT), {"fatCowCrates": "2.3.0"})
    assert [a.key for a in added] == ["fatCowCrates"]
    assert user.get("fatCowCrates")[0]["fuelKg"] == 2400


def test_complete_leaves_a_list_removed_at_its_own_version():
    user = cat('configVersion: "2.3.0"\nmm_facing:\n  numberOfTroops: 10\n  aiZones: []\n')
    assert complete(user, cat(DEFAULT), {"fatCowCrates": "2.3.0"}) == []
    assert not user.has("fatCowCrates")


def test_complete_leaves_an_undated_list_removed_at_any_version():
    user = cat('configVersion: "2.0.0"\nmm_facing:\n  numberOfTroops: 10\n')
    added = complete(user, cat(DEFAULT), {"fatCowCrates": "2.3.0"})
    assert [a.key for a in added] == ["fatCowCrates"]
    assert not user.has("aiZones")


def test_complete_without_the_table_adds_no_list():
    user = cat('configVersion: "2.2.0"\nmm_facing:\n  numberOfTroops: 10\n')
    assert complete(user, cat(DEFAULT)) == []
