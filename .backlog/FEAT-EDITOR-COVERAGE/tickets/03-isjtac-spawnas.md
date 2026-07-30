# 03 — `isJTAC` checkbox and a strict `spawnAs` dropdown in `CratesEditor`

**Status:** done

Depends on: 01 (category data), 02 (`tableFields` carries `choices`), and lot B ticket 02 (the schema
must stop advertising `GROUND_UNIT` and must declare the two values).

## Why

`CratesEditor` renders `desc`, `unit`, `weight`, `cratesRequired` and `side`. `isJTAC` and `spawnAs` are
preserved on save but not editable, so a Mission Maker cannot create a JTAC crate at all — even though
the engine supports it on any crate and the catalogue already ships two ground JTACs.

## What changes

- **`isJTAC`**: a checkbox column on every crate row. No family restriction — `_dispatchPostSpawn` lases
  any `isJTAC` descriptor regardless of `spawnAs` ([CTLD_crate.lua:2257](../../../src/CTLD_crate.lua#L2257)).
- **`spawnAs`**: a **strict** select offering exactly `GROUND` and `AIR`. Never free text: an unknown value
  silently becomes a ground spawn ([CTLD_utils.lua:1255](../../../src/CTLD_utils.lua#L1255)).
- **`AIR` resolution on save**: look up the crate's `unit` category via ticket 01 and write `AIRPLANE` or
  `HELICOPTER` into the catalogue. `GROUND` is written as `GROUND`, or omitted to match the shipped
  catalogue's convention — pick one and be consistent, since `spawnAs` absent already means ground.
- **Reading back**: a catalogue carrying `AIRPLANE` or `HELICOPTER` displays as `AIR`; absent or `GROUND`
  displays as `GROUND`. The two shipped drones must round-trip unchanged.
- **The two values come from the schema, never from the frontend.** Decided: `tableFields.spawnableCrates.spawnAs`
  declares `choices: [GROUND, AIR]` (authored by lot B ticket 02, surfaced by ticket 02 here). The reason is
  documentation, not plumbing — a Mission Maker editing the YAML by hand must be able to read the allowed
  values in the schema. Hardcoding them in `CratesEditor` would help only users of the app.

## Acceptance

- A crate can be made a JTAC from the UI, ground or air, and the resulting YAML loads in DCS.
- Opening and saving the shipped catalogue leaves the two drone entries byte-identical apart from
  lot C's changes.
- A helicopter type set to `AIR` writes `HELICOPTER`; a drone writes `AIRPLANE`.
- The select cannot produce a value outside the resolved set.

## Tests

- vitest: checkbox toggles `isJTAC` and the model round-trips.
- vitest: `AIR` + helicopter type → `HELICOPTER`; `AIR` + drone type → `AIRPLANE`; `GROUND` → ground.
- vitest: loading `AIRPLANE` displays `AIR`.
- vitest: the select's options come from the schema payload, not from a literal in the component.
- pytest: the shipped catalogue round-trips through load → save with no `spawnAs` drift.
