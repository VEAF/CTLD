"""Opening a configuration completes it with the missing scalar parameters, and saving stamps the version."""

import shutil
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.embed import wrap
from ctld_tools.install import install, read_config
from ctld_tools.web.app import app
from ctld_tools.web.state import session

client = TestClient(app)

REPO = Path(__file__).resolve().parents[3]
MIZ = REPO / "missions" / "Test_CTLDNEXT_01.miz"

#: Two settings the catalogue gained after a config was exported: the case that started this lot.
MISSING = ("crateSpawnGap", "enableParachuteDrop")


@pytest.fixture(autouse=True)
def _reset():
    session.reset()
    yield
    session.reset()


def _default() -> Catalog:
    return Catalog.load(resources.default_catalog_path())


def _stale_catalog(**overrides) -> Catalog:
    """The default catalogue as an older CTLD would have exported it: without `MISSING`."""
    cat = _default()
    for key in MISSING:
        cat.remove(key)
    for key, value in overrides.items():
        cat.set(key, value)
    return cat


def _stale_yaml(tmp_path: Path, **overrides) -> Path:
    path = tmp_path / "stale.yaml"
    _stale_catalog(**overrides).save(path)
    return path


def _open(path: Path) -> dict:
    resp = client.post("/api/catalog/load", json={"path": str(path)})
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_opening_a_file_adds_the_missing_parameters(tmp_path):
    body = _open(_stale_yaml(tmp_path))
    added = {a["key"]: a for a in body["completion"]}
    assert set(added) == set(MISSING)
    assert added["crateSpawnGap"]["value"] == _default().get("crateSpawnGap")
    assert body["values"]["crateSpawnGap"] == _default().get("crateSpawnGap")
    assert body["values"]["enableParachuteDrop"] == _default().get("enableParachuteDrop")


def test_the_completed_configuration_validates_clean(tmp_path):
    _open(_stale_yaml(tmp_path))
    assert client.get("/api/validate").json()["hasErrors"] is False


def test_a_complete_file_reports_nothing_added(tmp_path):
    path = tmp_path / "complete.yaml"
    _default().save(path)
    assert _open(path)["completion"] == []


def test_a_value_already_entered_is_kept(tmp_path):
    body = _open(_stale_yaml(tmp_path, hoverTime=99))
    assert body["values"]["hoverTime"] == 99
    assert "hoverTime" not in {a["key"] for a in body["completion"]}


def test_an_addition_can_be_undone(tmp_path):
    _open(_stale_yaml(tmp_path))
    assert client.request("DELETE", "/api/catalog/setting/crateSpawnGap").status_code == 200
    assert "crateSpawnGap" not in client.get("/api/catalog").json()["values"]


def test_opening_a_mission_adds_the_missing_parameters(tmp_path):
    miz = tmp_path / "stale.miz"
    shutil.copy(MIZ, miz)
    stale = _stale_catalog()
    install(str(miz), wrap(stale.dumps(), "configUser"), str(miz), catalog=stale, configuration_only=True)

    body = _open(miz)
    assert {a["key"] for a in body["completion"]} == set(MISSING)


def test_opening_the_default_adds_nothing():
    resp = client.post("/api/catalog/load-default")
    assert resp.status_code == 200
    assert "completion" not in resp.json() or resp.json()["completion"] == []


def test_a_mission_without_a_configuration_is_still_refused(tmp_path, pristine_miz):
    resp = client.post("/api/catalog/load", json={"path": str(pristine_miz)})
    assert resp.status_code == 422


def test_saving_writes_the_catalogue_version(tmp_path):
    path = _stale_yaml(tmp_path)
    cat = Catalog.load(path)
    cat.stamp_version("1.0.0")
    cat.save(path)
    _open(path)
    out = tmp_path / "saved.yaml"
    assert client.post("/api/catalog/save", json={"path": str(out)}).status_code == 200
    assert Catalog.load(out).get("configVersion") == _default().get("configVersion")


@pytest.mark.skipif(not (REPO / "CTLD.lua").is_file(), reason="CTLD.lua not built in this checkout")
def test_injecting_writes_the_catalogue_version(tmp_path):
    miz = tmp_path / "out.miz"
    shutil.copy(MIZ, miz)
    path = _stale_yaml(tmp_path)
    cat = Catalog.load(path)
    cat.stamp_version("1.0.0")
    cat.save(path)
    _open(path)
    assert client.post("/api/inject", json={"miz": str(miz), "configOnly": True}).status_code == 200
    found = read_config(miz)
    assert Catalog.loads(found.yaml).get("configVersion") == _default().get("configVersion")
