"""The scaffold is a valid, compilable (empty) user-config."""

from pathlib import Path

import pytest

from ctld_tools.genuser import render_user_config
from ctld_tools.reference import Reference
from ctld_tools.scaffold import write_scaffold
from ctld_tools.validate import load_user_config, validate

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"


@pytest.fixture(scope="module")
def ref() -> Reference:
    return Reference.from_src(SRC)


def test_scaffold_validates_clean_and_compiles(ref, tmp_path):
    path = tmp_path / "user-config.yaml"
    write_scaffold(path)
    cfg = load_user_config(path)
    assert validate(cfg, ref) == []  # everything commented → nothing to validate
    lua = render_user_config(cfg, ref)  # compiles with no error
    assert "if ctld == nil then ctld = {} end" in lua
