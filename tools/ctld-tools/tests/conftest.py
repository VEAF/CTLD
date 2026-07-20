"""Ensure the generated engine defaults exist before the tests run.

Since gen-au-build, `src/CTLD_config_defaults.lua` is a build artifact (git-ignored),
not committed. Tests that load the config (via lupa) need it, so regenerate it once
per session from the YAML source of truth.
"""

from pathlib import Path

import pytest

from ctld_tools.genconfig import generate_file

_REPO = Path(__file__).resolve().parents[3]


@pytest.fixture(scope="session", autouse=True)
def _ensure_generated_defaults():
    generate_file(_REPO / "src" / "CTLD_config.yaml", _REPO / "src" / "CTLD_config_defaults.lua")
