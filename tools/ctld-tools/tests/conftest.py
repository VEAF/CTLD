"""Shared pytest fixtures for ctld_tools's test suite."""

from __future__ import annotations

import zipfile
from pathlib import Path

import pytest

from ctld_tools.install import CONFIG_FILE, CONFIG_KEY, CONFIG_MARKER, L10N, MAP_RESOURCE
from ctld_tools.miz import read_mission, rebuild_triggers, write_miz
from ctld_tools.vendor import luadata

REPO = Path(__file__).resolve().parents[3]
MIZ = REPO / "missions" / "Test_CTLDNEXT_01.miz"


@pytest.fixture
def pristine_miz(tmp_path: Path) -> Path:
    """A copy of the shared dev mission with any ctld-tools install already stripped.

    `missions/Test_CTLDNEXT_01.miz` permanently carries a persisted `aiZones` configuration
    (FEAT-EXZ-AUTODISCOVERY ticket 01, 2026-09-24) -- a genuine, intentional change, not a
    test-fixture accident. A test asserting "before any ctld-tools install" behaviour needs an
    explicitly pristine starting point instead of relying on the shared mission being pristine,
    which by design it structurally no longer is. Only the configuration trigger/file/resource-map
    entry are stripped: the mission never carried an engine or sounds install (it loads the engine
    via its own `CTLD_DEV_ROOT` trigger), so there is nothing else of ours to remove.
    """
    mission = read_mission(MIZ)
    rebuild_triggers(mission, ours=[], markers={CONFIG_MARKER})
    staged = tmp_path / "_pristine_staged.miz"
    write_miz(mission, MIZ, staged)

    out = tmp_path / "pristine.miz"
    with zipfile.ZipFile(staged) as zin, zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename == f"{L10N}/{CONFIG_FILE}":
                continue
            data = zin.read(item.filename)
            if item.filename == MAP_RESOURCE:
                resmap = luadata.unserialize(data.decode("utf-8"))
                resmap.pop(CONFIG_KEY, None)
                data = ("mapResource = \n" + luadata.serialize(resmap, indent="\t")).encode("utf-8")
            zout.writestr(item, data)
    return out
