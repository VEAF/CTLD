"""The FastAPI backend: thin endpoints over the core (load/edit/save/validate/version-gap)."""

import pytest
from fastapi.testclient import TestClient

from ctld_tools.web.app import app
from ctld_tools.web.state import session

client = TestClient(app)

SAMPLE = """\
configVersion: "1.0.0"
mm_facing:
  numberOfTroops: 10
  spawnableCrates:
    Support:
    - unit: Ural-375
      desc: Ural Ammo
      weight: 1001.01
advanced:
  hoverTime: 10
"""

BAD_UNIT = SAMPLE.replace("unit: Ural-375", "unit: NotARealUnit")


@pytest.fixture(autouse=True)
def _reset():
    session.reset()
    yield
    session.reset()


def _load(text=SAMPLE):
    return client.post("/api/catalog/load", json={"text": text})


def test_health():
    assert client.get("/api/health").json() == {"status": "ok"}


def test_schema_endpoint_exposes_families_and_keys():
    body = client.get("/api/schema").json()
    assert isinstance(body["families"], list)
    assert isinstance(body["keys"], dict) and body["keys"]  # schema is non-empty
    assert "tableFields" not in body["keys"]  # the reserved section is not a setting


def test_schema_endpoint_exposes_table_fields():
    body = client.get("/api/schema").json()
    crates = body["tableFields"]["spawnableCrates"]
    assert crates["desc"] and crates["weight_kg"]  # field descriptions present


def test_load_text_then_get_catalog():
    snap = _load().json()
    assert snap["values"]["numberOfTroops"] == 10
    assert snap["values"]["configVersion"] == "1.0.0"
    # persisted in the session
    again = client.get("/api/catalog").json()
    assert again["values"]["hoverTime"] == 10


def test_load_default():
    snap = client.post("/api/catalog/load-default").json()
    assert snap["values"]["configVersion"] == "2.0.0"
    assert "spawnableCrates" in snap["values"]


def test_get_catalog_without_load_is_409():
    assert client.get("/api/catalog").status_code == 409


def test_load_requires_path_or_text():
    assert client.post("/api/catalog/load", json={}).status_code == 400


def test_load_malformed_yaml_is_422():
    r = client.post("/api/catalog/load", json={"text": "a:\n  - b\n c: bad"})
    assert r.status_code == 422


def test_set_existing_setting():
    _load()
    r = client.put("/api/catalog/setting", json={"key": "numberOfTroops", "value": 25})
    assert r.json() == {"key": "numberOfTroops", "value": 25}
    assert client.get("/api/catalog").json()["values"]["numberOfTroops"] == 25


def test_add_new_setting():
    _load()
    r = client.put("/api/catalog/setting", json={"key": "brandNew", "value": 7})
    assert r.json()["value"] == 7
    assert client.get("/api/catalog").json()["values"]["brandNew"] == 7


def test_delete_setting():
    _load()
    assert client.request("DELETE", "/api/catalog/setting/hoverTime").json() == {"removed": "hoverTime"}
    assert "hoverTime" not in client.get("/api/catalog").json()["values"]


def test_delete_unknown_is_404():
    _load()
    assert client.request("DELETE", "/api/catalog/setting/nope").status_code == 404


def test_save_and_yaml_roundtrip(tmp_path):
    _load()
    client.put("/api/catalog/setting", json={"key": "numberOfTroops", "value": 42})
    out = tmp_path / "saved.yaml"
    assert client.post("/api/catalog/save", json={"path": str(out)}).json() == {"saved": str(out)}
    assert "numberOfTroops: 42" in out.read_text(encoding="utf-8")
    assert "numberOfTroops: 42" in client.get("/api/catalog/yaml").json()["yaml"]


def test_validate_clean_and_bad_unit():
    _load()
    assert client.get("/api/validate").json()["hasErrors"] is False
    _load(BAD_UNIT)
    bad = client.get("/api/validate").json()
    assert bad["hasErrors"] is True
    assert any("NotARealUnit" in f["message"] for f in bad["findings"])


def test_version_gap_against_default():
    _load()  # SAMPLE is configVersion 1.0.0; default is 2.0.0
    gap = client.get("/api/version-gap").json()
    assert gap["fromVersion"] == "1.0.0"
    assert gap["toVersion"] == "2.0.0"
    assert gap["isEmpty"] is False
