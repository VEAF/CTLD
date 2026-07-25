# 04e — zones + mission lists + vehicle weights + full coverage gate

Status: 📋 todo
Type: tool (frontend + Python) + test

The remaining Data families, then close the **no-editing-gaps** gate.

- **Zones** (`troopZones` / `wpZones` / `AIZones`): positional arrays edited as named fields via the
  ported `_ZONE_FIELD_SCHEMAS` (positional↔named conversion) — a backend helper exposes the field
  layout + does the conversion; the frontend renders named editors.
- **Mission lists** (`transportPilotNames` — explicitly DoD — `extractableGroups`, `logisticUnits`):
  editable string lists. **`groundVehicleWeights`**: name → weight map.
- **Full coverage gate** (evolve FullGas's `test_schema_coverage.py`): every structured table field
  has an editor **and** an EN/FR description; the build fails otherwise. Deliberately-hidden keys →
  explicit reviewed allowlist, never a silent skip.

Files: `tools/ctld-tools/web/**`, `ctld_tools/web/**`, `tests/**`. Depends on: 04a–04d.
