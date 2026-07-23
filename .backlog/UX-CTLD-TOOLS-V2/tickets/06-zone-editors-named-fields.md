# 06 — Zone editors with named fields (troopZones / wpZones / AIZones)

Status: ready

## What to build

Add the Zones section to the catalogue tree. The three zone tables (`troopZones`,
`wpZones`, `AIZones`) are currently stored as positional arrays with no field names —
v2 presents them with named fields so the MM never has to count array indices.

End-to-end behaviour:
- Tree node "Zones" expands to "Troop Zones", "Waypoint Zones", "AI Zones".
- Each sub-node expands to list its zone entries by zone name (position 0 of the array).
- 4 visual states per entry.
- Clicking a zone entry opens the form with named fields mapped from the positional
  schema:
  - `troopZone`: Zone name, Colour, Troop limit, Can pickup, Group size, Icon ID
    (optional).
  - `wpZone`: Zone name, Colour, Can pickup, Side.
  - `AIZone`: Zone name, Mode, Side (+ optional extra fields).
- Apply / Delete / Cancel. Restore for deleted entries. Add from the sub-node.
- The positional field schema is declared in `CTLD_config_schema.yaml` (new section for
  zone field definitions) and read by `Reference` via a new `zone_fields(zone_type)`
  accessor.
- `test_zone_fields.py`: asserts that named-field → positional write → positional read
  → named-field round-trips without loss.

## Acceptance criteria

- [ ] Tree renders all three zone tables under "Zones"; entries identified by zone name.
- [ ] 4 visual states per entry (default / modified* / added green / deleted strikethrough).
- [ ] `troopZone` form shows 5–6 named fields mapped from the positional array; no
  index labels visible to the MM.
- [ ] `wpZone` and `AIZone` forms likewise.
- [ ] Apply commits the change to `EditModel` as a patch on the positional array (fields
  written back in correct positional order).
- [ ] Add from sub-node: blank named-field form; Apply inserts a new positional array
  entry (green in tree).
- [ ] Delete marks entry for removal; Restore un-marks.
- [ ] `CTLD_config_schema.yaml` extended with positional field definitions for all three
  zone types (field name, position index, type, description).
- [ ] `Reference.zone_fields(zone_type)` accessor added and covered by `test_reference.py`.
- [ ] `test_zone_fields.py` round-trip tests pass for all three zone types.
- [ ] `test_catalogue_tree.py` extended for zone states.

## Blocked by

- Ticket 02 (scalars editor)
