"""The schema and catalogue must describe what the engine actually reads.

FIX-CATALOGUE-TRUTH. Four blocks lied to the Mission Maker: a dead positional format for `aiZones`,
a `spawnAs` value in no lookup table, a `modTypes` shape the engine cannot walk, and a
`spawnableCratesModels` field that never reaches DCS. Each is cheap to assert against the Lua that
consumes it, so each gets a test rather than another review pass.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from ruamel.yaml import YAML

# Repo root: tools/ctld-tools/tests/ -> ../../..
ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src"


def _yaml(path: Path):
    return YAML(typ="safe").load(path.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def schema():
    return _yaml(SRC / "CTLD_config_schema.yaml")


@pytest.fixture(scope="module")
def catalogue():
    cfg = _yaml(SRC / "CTLD_config.yaml")
    flat: dict = {}
    for section, value in cfg.items():
        if section in ("mm_facing", "advanced") and isinstance(value, dict):
            flat.update(value)
        else:
            flat[section] = value
    return flat


@pytest.fixture(scope="module")
def zone_lua():
    return (SRC / "CTLD_zone.lua").read_text(encoding="utf-8")


# ── aiZones: the fields and enums must be the engine's ──────────────────────────


def test_the_dead_positional_aizones_block_is_gone(schema):
    """`tableFields.AIZones` described zoneName/mode/side — three fields never read, in src/ or legacy."""
    assert "AIZones" not in schema["tableFields"]
    assert "aiZones" in schema["tableFields"]


def test_aizones_fields_are_exactly_what_the_engine_reads(schema, zone_lua):
    loader = zone_lua[zone_lua.index("function CTLDZoneManager:_loadAIZonesFromConfig") :]
    loader = loader[: loader.index("\nfunction ")]
    engine_fields = set(re.findall(r"\bentry\.(\w+)", loader))
    documented = set(schema["tableFields"]["aiZones"])
    assert engine_fields, "could not find any entry.<field> read — has the loader been renamed?"
    assert documented == engine_fields, (
        f"documented but unread: {sorted(documented - engine_fields)}; "
        f"read but undocumented: {sorted(engine_fields - documented)}"
    )


@pytest.mark.parametrize(
    ("field", "lua_table"),
    [("coalition", "VALID_COALITION"), ("cargoType", "VALID_CARGO"), ("aiDropMode", "VALID_DROP_MODE")],
)
def test_aizones_enum_matches_the_engines_own_table(schema, zone_lua, field, lua_table):
    """Take the vocabulary from the engine, never retype it — the UI must not drift from the runtime."""
    block = re.search(rf"local {lua_table}\s*=\s*\{{(.*?)\}}", zone_lua, re.S)
    assert block, f"{lua_table} not found in CTLD_zone.lua"
    engine_values = set(re.findall(r"(\w+)\s*=\s*true", block.group(1)))
    assert set(schema["tableFields"]["aiZones"][field]["choices"]) == engine_values


def test_aizones_coalition_is_documented_as_a_word_not_a_number(schema):
    """Everywhere else a coalition is the numeric `side`; here the engine matches strings.

    An editor reusing the numeric widget would write a number the engine silently reads as
    "both coalitions" — the same data-corruption class as the boolean-typed `jtac` field.
    """
    en = schema["tableFields"]["aiZones"]["coalition"]["en"].lower()
    assert "not a number" in en


# ── spawnAs: only values that work ─────────────────────────────────────────────


def test_ground_unit_is_gone_from_the_schema(schema):
    """GROUND_UNIT is in no lookup table; unknown values silently fall back to Group.Category.GROUND."""
    assert "GROUND_UNIT" not in (SRC / "CTLD_config_schema.yaml").read_text(encoding="utf-8")


def test_spawnas_declares_only_the_two_usable_values(schema):
    assert schema["tableFields"]["spawnableCrates"]["spawnAs"]["choices"] == ["GROUND", "AIR"]


def test_the_catalogue_uses_no_spawnas_outside_the_resolved_set(catalogue):
    """`AIR` is resolved to AIRPLANE/HELICOPTER on save, so those are what the YAML may carry."""
    allowed = {"GROUND", "AIRPLANE", "HELICOPTER"}
    used = {
        entry["spawnAs"]
        for entries in (catalogue.get("spawnableCrates") or {}).values()
        for entry in entries or []
        if isinstance(entry, dict) and entry.get("spawnAs") is not None
    }
    assert used <= allowed, f"unusable spawnAs value(s) in the catalogue: {sorted(used - allowed)}"


# ── modTypes: a list, because the engine walks it with ipairs ───────────────────


def test_modtypes_is_a_list(catalogue):
    """It shipped as `{}` — a map — while CTLD_typeCollector iterates it with ipairs."""
    assert isinstance(catalogue["modTypes"], list)


def test_modtypes_has_a_description_explaining_what_it_is_for(schema):
    entry = schema["modTypes"]
    assert entry.get("group"), "an uncovered setting lands in the generic bucket"
    assert "validation" in entry["description"]["en"].lower()


# ── spawnableCratesModels: only fields _spawnStatic actually copies ─────────────


def test_the_dead_category_field_is_gone(catalogue):
    """`_spawnStatic` never copies it, and `dynAddStatic` forces category='Cargos' regardless."""
    for mode, model in catalogue["spawnableCratesModels"].items():
        assert "category" not in model, f"{mode} still declares the inert category field"


def test_crate_models_declare_only_fields_the_engine_reads(catalogue):
    crate_lua = (SRC / "CTLD_crate.lua").read_text(encoding="utf-8")
    static = crate_lua[crate_lua.index("function CTLDCrateManager:_spawnStatic") :]
    static = static[: static.index("\nfunction ")]
    for mode, model in catalogue["spawnableCratesModels"].items():
        for field in model:
            assert f"model.{field}" in static, f"{mode}.{field} is authored but never read"


# ── dropCrate: removed, and it must not come back ──────────────────────────────


def test_dropcrate_and_its_setting_are_gone():
    """Unreachable: no menu entry called it, and parachuteCrates serves the airborne drop."""
    offenders = []
    for lua in sorted(SRC.rglob("*.lua")):
        if lua.name == "CTLD_config_default_yaml.lua":  # generated: the catalogue as a string
            continue
        for n, line in enumerate(lua.read_text(encoding="utf-8").splitlines(), 1):
            # `RandomReal("dropCrates", ...)` is an unrelated call site.
            if re.search(r"\bdropCrate\b|\bmaxDropHeight\b", line):
                offenders.append(f"{lua.relative_to(ROOT)}:{n}  {line.strip()[:80]}")
    assert offenders == []


def test_maxdropheight_is_gone_from_the_catalogue_and_schema(catalogue, schema):
    assert "maxDropHeight" not in catalogue
    assert "maxDropHeight" not in schema


# ── Drone orbit is governed by settings, not by a per-crate block ───────────────
# FEAT-JTAC-DRONE-GLOBALS. The four globals were rebased onto the values the two shipped drones
# used, so removing `specificParams` changes only what we chose to change.


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("JTAC_droneAltitude", 3000),  # was 4000 against a per-crate 3000
        ("JTAC_droneRadiusNoLase", 2000),
        ("JTAC_droneRadiusOnLase", 1000),
        ("JTAC_droneSpeed", 150),
    ],
)
def test_drone_global_carries_the_value_it_replaced(catalogue, key, value):
    assert catalogue[key] == value


def test_the_single_radius_setting_is_retired(catalogue, schema):
    """One key could not express both the searching and the lasing radius."""
    assert "JTAC_droneRadius" not in catalogue
    assert "JTAC_droneRadius" not in schema


def test_no_crate_carries_specificparams(catalogue):
    for section, entries in (catalogue.get("spawnableCrates") or {}).items():
        for entry in entries or []:
            assert "specificParams" not in entry, f"{section}: {entry.get('desc')}"


def test_specificparams_is_gone_from_the_crate_schema(schema):
    assert not [f for f in schema["tableFields"]["spawnableCrates"] if f.startswith("specificParams")]


def test_the_troop_path_keeps_specificparams(catalogue):
    """`specificParams.task` on loadableGroups is Feature I — a different feature sharing the name.

    Only the crate block was retired. This guards the boundary: nothing here should have reached
    CTLD_troop.lua.
    """
    troop_lua = (SRC / "CTLD_troop.lua").read_text(encoding="utf-8")
    assert "_assignPostSpawnTask" in troop_lua
    assert "specificParams" in troop_lua


def test_spawn_and_orbit_read_the_same_altitude_setting():
    """They used to disagree: born at JTAC_droneAltitude, orbiting at the per-crate value."""
    utils_lua = (SRC / "CTLD_utils.lua").read_text(encoding="utf-8")
    jtac_lua = (SRC / "CTLD_jtac.lua").read_text(encoding="utf-8")
    assert 'ctld.gs("JTAC_droneAltitude")' in utils_lua  # buildGroupUnitDef, spawn
    assert jtac_lua.count('ctld.gs("JTAC_droneAltitude")') == 2  # _setOrbitRoute + _setOrbitTask
    assert 'ctld.gs("JTAC_droneSpeed")' in utils_lua  # spawn speed, was hardcoded 54 m/s


def test_the_orbit_no_longer_threads_a_per_crate_params_table():
    jtac_lua = (SRC / "CTLD_jtac.lua").read_text(encoding="utf-8")
    assert "orbitParams" not in jtac_lua
