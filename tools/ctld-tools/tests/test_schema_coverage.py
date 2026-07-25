"""No-editing-gaps coverage gate (CTLD-TOOLS-WEBAPP): every structured table field the web
app edits is documented with EN + FR help, and every zone-editor field is documented.

Evolves FullGas's test_schema_coverage.py to the complete-catalogue model (schema tableFields
instead of the retired Reference). The build fails if a field lacks a description — so a new
data field cannot ship without help text.
"""

from pathlib import Path

import pytest

from ctld_tools.schema import Schema
from ctld_tools.web.zones import ZONE_FIELD_SCHEMAS

_SCHEMA = Schema.load(Path(__file__).resolve().parents[3] / "src" / "CTLD_config_schema.yaml")
_TABLE_FIELDS = _SCHEMA.table_fields()

# Tables the web app edits with a bespoke editor — each must be documented (no silent gap).
_EXPECTED_TABLES = {
    "spawnableCrates",
    "loadableGroups",
    "capabilitiesByType",
    "troopZones",
    "wpZones",
    "AIZones",
    "groundVehicleWeights",
}

_FIELD_PAIRS = [(table, field) for table, fields in _TABLE_FIELDS.items() for field in fields]


def test_expected_tables_are_documented():
    missing = _EXPECTED_TABLES - set(_TABLE_FIELDS)
    assert not missing, f"undocumented structured tables: {sorted(missing)}"


@pytest.mark.parametrize("table,field", _FIELD_PAIRS)
def test_field_has_en_and_fr(table, field):
    meta = _TABLE_FIELDS[table][field]
    assert isinstance(meta, dict), f"{table}.{field} has no description block"
    assert meta.get("en"), f"{table}.{field} missing EN description"
    assert meta.get("fr"), f"{table}.{field} missing FR description"


@pytest.mark.parametrize("ztype", sorted(ZONE_FIELD_SCHEMAS))
def test_zone_editor_fields_are_documented(ztype):
    documented = set(_TABLE_FIELDS.get(ztype, {}))
    for field in ZONE_FIELD_SCHEMAS[ztype]:
        assert field["name"] in documented, f"{ztype}.{field['name']} editor field is undocumented"
