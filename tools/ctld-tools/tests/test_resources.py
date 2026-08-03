"""The tool locates every payload it ships with — catalogue, schema, engine, beacon sounds.

FEAT-ONE-CLICK-INSTALL ticket 01. These are what the exe installs into a `.miz`, so "the resolver
found nothing" must never be a quiet outcome: an empty engine fails at mission start, hours away
from the mistake.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from ctld_tools import resources

REPO = Path(__file__).resolve().parents[3]


def test_catalogue_and_schema_resolve_in_a_checkout():
    assert resources.default_catalog_path() == REPO / "src" / "CTLD_config.yaml"
    assert resources.schema_path() == REPO / "src" / "CTLD_config_schema.yaml"
    assert resources.default_catalog_path().is_file()
    assert resources.schema_path().is_file()


def test_engine_resolves_to_the_built_deliverable():
    assert resources.engine_path() == REPO / "CTLD.lua"


def test_sounds_resolve_to_the_repo_assets():
    assert [p.name for p in resources.sound_paths()] == ["beacon.ogg", "beaconsilent.ogg"]
    for path in resources.sound_paths():
        assert path.parent == REPO / "assets"
        assert path.is_file(), f"{path} is a committed asset and must exist"


def test_reading_the_sounds_returns_their_bytes():
    sounds = resources.read_sounds()
    assert set(sounds) == set(resources.SOUND_NAMES)
    for name, data in sounds.items():
        assert len(data) == (REPO / "assets" / name).stat().st_size
        assert data[:4] == b"OggS", f"{name} should be an Ogg container"


@pytest.mark.skipif(not (REPO / "CTLD.lua").is_file(), reason="CTLD.lua not built in this checkout")
def test_reading_the_engine_returns_the_built_bytes():
    data = resources.read_engine()
    assert len(data) == (REPO / "CTLD.lua").stat().st_size
    assert b"ctld.VERSION" in data


def test_a_missing_engine_names_the_build_script(monkeypatch, tmp_path):
    """A fresh checkout has no CTLD.lua; the message must say how to get one."""
    monkeypatch.setattr(resources, "engine_path", lambda: tmp_path / "CTLD.lua")
    with pytest.raises(FileNotFoundError) as excinfo:
        resources.read_engine()
    assert "merge_CTLD.ps1" in str(excinfo.value)


def test_the_frozen_layout_puts_every_payload_in_one_place(monkeypatch, tmp_path):
    """In the exe, --add-data flattens all payloads into _MEIPASS/ctld_data."""
    monkeypatch.setattr(resources.sys, "frozen", True, raising=False)
    monkeypatch.setattr(resources.sys, "_MEIPASS", str(tmp_path), raising=False)
    monkeypatch.delenv("CTLD_TOOLS_SRC", raising=False)

    bundle = tmp_path / "ctld_data"
    assert resources.src_dir() == bundle
    assert resources.engine_path() == bundle / "CTLD.lua"
    assert [p.parent for p in resources.sound_paths()] == [bundle, bundle]


def test_the_src_override_still_only_moves_the_catalogue(monkeypatch, tmp_path):
    """CTLD_TOOLS_SRC predates the engine and the sounds and keeps its narrower meaning."""
    monkeypatch.setenv("CTLD_TOOLS_SRC", str(tmp_path))
    assert resources.src_dir() == tmp_path
    assert resources.engine_path() == REPO / "CTLD.lua"


# ── One version, read from ctld.VERSION (FEAT-TOOL-VERSION-AND-DOCS ticket 01) ───────


def test_the_tool_reports_the_engine_version():
    """One source of truth. pyproject's own number drifted to 0.1.0 and stayed; this cannot."""
    declared = resources.version_from((REPO / "src" / "CTLD_config.lua").read_bytes())
    assert declared, "src/CTLD_config.lua must declare ctld.VERSION"
    assert resources.ctld_version() == declared


def test_a_prerelease_suffix_survives():
    assert resources.version_from('ctld.VERSION = "2.0.0-rc3"') == "2.0.0-rc3"
    assert resources.version_from('ctld.VERSION = "2.1.0"') == "2.1.0"


def test_lua_without_a_version_reads_as_none():
    assert resources.version_from("-- nothing here") is None


def test_no_version_anywhere_is_reported_not_invented(monkeypatch, tmp_path):
    """A partial tree must not yield a number that would end up in an install report."""
    monkeypatch.setattr(resources, "engine_path", lambda: tmp_path / "CTLD.lua")
    monkeypatch.setattr(resources, "src_dir", lambda: tmp_path)
    assert resources.ctld_version() == resources.UNKNOWN_VERSION


def test_a_prerelease_points_at_the_dev_documentation():
    """`mike deploy` only runs on a tag, so an rc has no pages of its own — `dev` is the honest link."""
    assert resources.docs_version("2.0.0-rc3") == "dev"
    assert resources.docs_version("2.1.0-rc1") == "dev"


def test_a_stable_points_at_its_own_documentation():
    assert resources.docs_version("2.0.0") == "2.0.0"
    assert resources.docs_version("2.1.3") == "2.1.3"


def test_an_unknown_version_falls_back_to_dev():
    assert resources.docs_version(resources.UNKNOWN_VERSION) == "dev"
