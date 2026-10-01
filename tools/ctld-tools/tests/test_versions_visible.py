"""The configuration's version and the catalogue's are visible in `validate` and in the API."""

from pathlib import Path

from fastapi.testclient import TestClient
from typer.testing import CliRunner

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.cli import app as cli_app
from ctld_tools.web.app import app as web_app

runner = CliRunner()
client = TestClient(web_app)


def _default() -> Catalog:
    return Catalog.load(resources.default_catalog_path())


def _stamped(tmp_path: Path, version: str) -> Path:
    cat = _default()
    cat.stamp_version(version)
    path = tmp_path / "cfg.yaml"
    cat.save(path)
    return path


def test_validate_prints_both_versions_when_they_differ(tmp_path):
    result = runner.invoke(cli_app, ["validate", "--yaml", str(_stamped(tmp_path, "1.9.0"))])
    assert "1.9.0" in result.output
    assert str(_default().get("configVersion")) in result.output


def test_validate_prints_no_version_line_when_they_match(tmp_path):
    current = str(_default().get("configVersion"))
    result = runner.invoke(cli_app, ["validate", "--yaml", str(_stamped(tmp_path, current))])
    assert "validate: OK" in result.output
    assert "catalogue version" not in result.output


def test_the_api_version_carries_the_catalogue_version():
    body = client.get("/api/version").json()
    assert body["catalogue"] == str(_default().get("configVersion"))
