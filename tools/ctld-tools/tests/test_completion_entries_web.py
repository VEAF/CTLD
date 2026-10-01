"""Opening an older configuration completes the fields of its list entries; the additions can be undone."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.web.app import app
from ctld_tools.web.state import session

client = TestClient(app)

SPAWN_FIELDS = ("crateSpawnSector", "crateSpawnDistance")


@pytest.fixture(autouse=True)
def _reset():
    session.reset()
    yield
    session.reset()


def _default() -> Catalog:
    return Catalog.load(resources.default_catalog_path())


def _stale_yaml(tmp_path: Path, version: str = "2.0.0") -> Path:
    """The default catalogue as it was before the crate spawn fields: no spawn fields, no model size."""
    cat = _default()
    for entry in cat.get("capabilitiesByType").values():
        for fld in SPAWN_FIELDS:
            entry.pop(fld, None)
    for model in cat.get("spawnableCratesModels").values():
        model.pop("size", None)
    cat.stamp_version(version)
    path = tmp_path / "stale.yaml"
    cat.save(path)
    return path


def _open(path: Path) -> dict:
    resp = client.post("/api/catalog/load", json={"path": str(path)})
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_the_catalogue_version_is_2_1_0():
    assert str(_default().get("configVersion")) == "2.1.0"


def test_opening_an_older_file_completes_the_aircraft_and_the_crate_models(tmp_path):
    body = _open(_stale_yaml(tmp_path))
    fields = {(a["container"], a["entry"], a["key"]): a["value"] for a in body["completion"] if a.get("container")}
    expected = _default().get("capabilitiesByType")["Mi-8MT"]["crateSpawnDistance"]
    assert fields[("capabilitiesByType", "Mi-8MT", "crateSpawnDistance")] == expected
    assert ("spawnableCratesModels", "load", "size") in fields
    mi8 = body["values"]["capabilitiesByType"]["Mi-8MT"]
    assert mi8["crateSpawnSector"] == "side"


def test_a_scalar_addition_has_no_container(tmp_path):
    cat = Catalog.load(_stale_yaml(tmp_path))
    cat.remove("crateSpawnGap")
    cat.save(tmp_path / "stale.yaml")
    body = _open(tmp_path / "stale.yaml")
    gap = next(a for a in body["completion"] if a["key"] == "crateSpawnGap")
    assert gap.get("container") is None and gap.get("entry") is None


def test_a_current_file_that_lacks_the_fields_is_left_as_it_is(tmp_path):
    body = _open(_stale_yaml(tmp_path, version="2.1.0"))
    assert body["completion"] == []
    assert "crateSpawnSector" not in body["values"]["capabilitiesByType"]["Mi-8MT"]


def test_an_aircraft_type_added_by_the_mission_maker_is_untouched(tmp_path):
    cat = Catalog.load(_stale_yaml(tmp_path))
    cat.get("capabilitiesByType")["MyOwnHeli"] = {"maxCratesOnboard": 2}
    cat.save(tmp_path / "stale.yaml")
    body = _open(tmp_path / "stale.yaml")
    assert body["values"]["capabilitiesByType"]["MyOwnHeli"] == {"maxCratesOnboard": 2}


def test_an_entry_field_addition_can_be_undone(tmp_path):
    _open(_stale_yaml(tmp_path))
    resp = client.request(
        "DELETE",
        "/api/catalog/entry-field",
        params={"container": "capabilitiesByType", "entry": "Mi-8MT", "field": "crateSpawnSector"},
    )
    assert resp.status_code == 200
    mi8 = client.get("/api/catalog").json()["values"]["capabilitiesByType"]["Mi-8MT"]
    assert "crateSpawnSector" not in mi8 and "crateSpawnDistance" in mi8


def test_undoing_an_unknown_entry_field_is_404(tmp_path):
    _open(_stale_yaml(tmp_path))
    resp = client.request(
        "DELETE", "/api/catalog/entry-field", params={"container": "capabilitiesByType", "entry": "Nope", "field": "x"}
    )
    assert resp.status_code == 404


def test_saving_then_reopening_adds_nothing(tmp_path):
    _open(_stale_yaml(tmp_path))
    out = tmp_path / "saved.yaml"
    assert client.post("/api/catalog/save", json={"path": str(out)}).status_code == 200
    assert Catalog.load(out).get("configVersion") == _default().get("configVersion")
    assert _open(out)["completion"] == []


def test_a_field_removed_after_saving_stays_removed(tmp_path):
    _open(_stale_yaml(tmp_path))
    client.request(
        "DELETE",
        "/api/catalog/entry-field",
        params={"container": "capabilitiesByType", "entry": "Mi-8MT", "field": "crateSpawnSector"},
    )
    out = tmp_path / "saved.yaml"
    client.post("/api/catalog/save", json={"path": str(out)})
    body = _open(out)
    assert "crateSpawnSector" not in body["values"]["capabilitiesByType"]["Mi-8MT"]


def test_the_version_gap_lists_a_default_that_differs_from_a_kept_value(tmp_path):
    cat = Catalog.load(_stale_yaml(tmp_path))
    cat.get("capabilitiesByType")["Mi-8MT"]["crateSpawnDistance"] = 9.0
    cat.save(tmp_path / "stale.yaml")
    _open(tmp_path / "stale.yaml")
    gap = client.get("/api/version-gap").json()
    changed = [c for c in gap["changedFields"] if c["entry"] == "Mi-8MT" and c["field"] == "crateSpawnDistance"]
    assert changed and changed[0]["old"] == 9.0
    assert client.get("/api/catalog").json()["values"]["capabilitiesByType"]["Mi-8MT"]["crateSpawnDistance"] == 9.0
