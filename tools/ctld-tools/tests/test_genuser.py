"""gen-user compiles operations to helper calls (names resolved) and the result
drives the real ctld.userSetup helpers end to end."""

from pathlib import Path

import lupa
import pytest

from ctld_tools.genuser import UserConfigError, render_user_config
from ctld_tools.luaconfig import IDENTITY_TR, _to_py
from ctld_tools.reference import Reference

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"
YAML = SRC / "CTLD_config.yaml"


@pytest.fixture(scope="module")
def ref() -> Reference:
    return Reference.from_src(SRC)


def _p(path: Path) -> str:
    return str(path).replace("\\", "/")


def _run_user_config(ref, cfg: dict, tmp_path: Path) -> dict:
    """Render cfg to userConfig.lua, run it against the real helpers, return settings."""
    user_lua = tmp_path / "CTLD_userConfig.lua"
    user_lua.write_text(render_user_config(cfg, ref), encoding="utf-8")

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    src = _p(SRC) + "/"
    lua.execute(f"""
        ctld = {{}}; ctldLogPath = ""
        dofile("{src}core/class.lua")
        dofile("{src}CTLD_aasystem.lua")
        dofile("{src}CTLD_config.lua")
        ctld.tr = {IDENTITY_TR}
        ctld.utils = {{ log = function() end }}
        ctld.logWarning = function() end
        do
            local fh = assert(io.open("{_p(YAML)}", "r"))
            ctld.configDefault = fh:read("*a"); fh:close()
        end
        CTLDConfig.get():load()
        dofile("{src}CTLD_userSetup.lua")
        dofile("{_p(user_lua)}")
        ctld.runUserSetup()
    """)
    return _to_py(lua.eval("CTLDConfig.get().settings"))


def test_compiles_operations_with_resolved_names(ref):
    cfg = {
        "settings": {"numberOfTroops": 8},
        "crates": {
            "add": [{"section": "Support", "name": "Ural Ammo", "unit": "Ural-375", "side": 1, "weight_kg": 2000}],
            "remove": ["Heavy Tank - Abrams"],
            "patch": [{"name": "Humvee - TOW", "cratesRequired": 3}],
        },
        "troops": {"remove": ["5x - Mortar Squad"]},
        "arrays": {"transportPilotNames": ["heli_x"]},
    }
    lua = render_user_config(cfg, ref)
    assert 'ctld.addCrate("Support", {' in lua
    assert 'desc = ctld.tr("Ural Ammo")' in lua  # name -> desc, wrapped
    assert "ctld.removeCrate(1000.05)" in lua  # resolved from "Heavy Tank - Abrams"
    assert "ctld.patchCrate(1000.02," in lua  # resolved from "Humvee - TOW"
    assert 'ctld.removeTroopGroup("5x - Mortar Squad")' in lua
    assert 'ctld.addTo("transportPilotNames", "heli_x")' in lua
    assert "ctld.numberOfTroops: 8" in lua  # scalar section


def test_compiles_patch_troop(ref):
    lua = render_user_config({"troops": {"patch": [{"name": "Standard Group", "inf": 9}]}}, ref)
    assert 'ctld.patchTroopGroup("Standard Group", {' in lua
    assert "inf = 9" in lua


def test_patch_crate_maps_weight_kg_to_weight(ref):
    # weight_kg in a patch targets the runtime crate key `weight` (as add does).
    lua = render_user_config({"crates": {"patch": [{"name": "Humvee - TOW", "weight_kg": 987654}]}}, ref)
    assert "weight = 987654" in lua
    assert "weight_kg" not in lua


def test_errors_block_generation(ref):
    with pytest.raises(UserConfigError):
        render_user_config({"crates": {"remove": ["No Such Crate"]}}, ref)


def test_end_to_end_drives_real_helpers(ref, tmp_path):
    """The generated userConfig, run against the real helpers, mutates settings."""
    cfg = {
        "crates": {
            "add": [{"section": "Support", "name": "Ural Ammo", "unit": "Ural-375", "side": 1, "weight_kg": 2000}],
            "remove": ["Heavy Tank - Abrams"],
        }
    }
    settings = _run_user_config(ref, cfg, tmp_path)

    support = settings["spawnableCrates"]["Support"]
    assert any(e.get("weight") == 2000 and e.get("desc") == "Ural Ammo" for e in support)
    all_weights = [e.get("weight") for sec in settings["spawnableCrates"].values() for e in sec]
    assert 1000.05 not in all_weights  # Abrams removed


def test_patch_troop_end_to_end(ref, tmp_path):
    """patch troop compiles to patchTroopGroup and the real helper mutates the group."""
    settings = _run_user_config(ref, {"troops": {"patch": [{"name": "Standard Group", "inf": 42}]}}, tmp_path)
    group = next(g for g in settings["loadableGroups"] if g.get("name") == "Standard Group")
    assert group["inf"] == 42
