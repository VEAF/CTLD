"""Round-trip parity: ctld-config.yaml -> gen-config -> Lua -> settings == reference.

The reference fixture was frozen from the original CTLD_config.lua defaults using a
DISTINCTIVE translator, so a missing ctld.tr wrapper on any desc/name would diverge.
"""

import json
from pathlib import Path

import lupa
import pytest

from ctld_tools.genconfig import generate_file
from ctld_tools.luaconfig import _to_py, load_default_settings

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"
YAML = SRC / "CTLD_config.yaml"
FIXTURE = Path(__file__).parent / "data" / "reference_settings.json"

DISTINCTIVE = 'function(key, default) return "<<TR:" .. (default or key) .. ">>" end'


def _load_generated(lua_path: Path, tr: str) -> dict:
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(f"ctld = {{}}; ctld.tr = {tr}")
    lua.execute(f'dofile("{str(lua_path).replace(chr(92), "/")}")')
    return _to_py(lua.eval("ctld.__configDefaults"))


@pytest.fixture(scope="module")
def reference() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def test_yaml_regenerates_settings_matching_reference(tmp_path, reference):
    out = tmp_path / "gen.lua"
    generate_file(YAML, out)
    generated = _load_generated(out, DISTINCTIVE)
    assert generated == reference


def test_loaded_config_matches_reference(reference):
    """Post-switchover: CTLDConfig:load() copying ctld.__configDefaults yields the
    same settings as the original inline defaults (the migration parity guard)."""
    loaded = load_default_settings(SRC, tr=DISTINCTIVE)
    assert loaded == reference
