# 01 — The six findings

**Status:** done

## 1 · Troop-group editor corrupted the data (highest severity)

`TROOP_FIELDS` typed `jtac` as `boolean`; the catalogue ships `jtac: 1` and `jtac: 2`. A checkbox that
no number could tick explains all three symptoms FullGas reported — the two JTAC groups looking
identical, "Single JTAC" looking empty — but the real damage was on write: toggling it replaced the
count with `true`/`false` in the user's YAML.

Fixed to `number`. Guarded on both sides: `tables.test.ts` pins every non-`name` field as a number,
and `test_web_app.py` asserts the catalogue's own groups only ever hold string names and integer
counts, so a legitimate future boolean forces a deliberate frontend change instead of silent
corruption.

## 2 · Eleven double-encoded French descriptions

`rÃ©fÃ©rence` for `référence`: UTF-8 bytes written out as cp1252. `git log -S` dates it to `5e4dc50`
(PR #66); it stayed invisible until the FR UI rendered those strings, so review never caught it.

Repaired byte-level (`encode('cp1252').decode('utf-8')`) rather than through a YAML round-trip, which
would have reflowed a 1000-line file for eleven strings. `tests/test_encoding.py` now fails on any
`Ã`/`Â`/`â€` sequence in the authored YAML and locale files — plus a test that the detector still
fires, because a guard that cannot fail is not a guard.

## 3 · `AIZones` — a dead key with a convincing editor

The engine reads `ctld.gs("aiZones")` (`CTLD_zone.lua:706`). Nothing in `src/` reads `AIZones`, and
`migration/source/CTLD.lua` has neither spelling. So the catalogue shipped four AI zones with no effect
in game, `zones.py` described them with a positional schema that was also wrong (3 fields for the 5
positions present), and PR #68 gave that schema a dedicated editor — making dead data look configured.

**FullGas's fix would have gone wrong here.** He recommended adding `'aiZones'` to `ZONE_TYPES`, but
`aiZones` entries are named records (`dcsZoneName`, `coalition`, `isPickup`, `isDropoff`, `cargoType`,
`troopStock`, `vehicleStock`), not positional arrays — `ZonesEditor` would have mangled them. So:
`AIZones` removed everywhere (catalogue, schema, zone schemas, nav), oracle and `CTLD.lua` regenerated,
`aiZones` defaulted to `[]` (the engine does `#entries`) and its record format documented in the
schema. It keeps the raw editor until it gets a proper one — a wrong editor is worse than none.

## 4 · `logisticUnits` belongs to Zones

My first reading was wrong: I argued these were unit names rather than zones. They are zones — mobile
ones, centred on a vehicle instead of drawn in the Mission Editor. FullGas's rule holds: classify by
what the thing is, not by what it is for. Moved.

## 5 · `nbLimitSpawnedTroops` · 6 · `beaconIconColor`

Both are short positional arrays where the index carries the meaning, and both rendered as raw JSON
(`[0, 0]`, `[1, 0.5, 0, 1]`). New `PositionalEditor`: named fields, per-field hints, and for the colour
a live swatch (verified rendering `rgb(255, 128, 0)` for the default orange). Length is preserved on
write. Formats documented in the schema: DCS coalition indices for the first, DCS RGBA for the second
— including that the engine forces the circle fill to alpha 0.2 regardless.

## Verification

154 pytest · 99 vitest · svelte-check clean · ruff + mypy clean. Parity oracle regenerated (135 keys)
and `CTLD.lua` rebuilt; no test referenced the `AIZones` key (only the `_loadAIZonesFromConfig`
function name). Editors confirmed in a running exe-mode server, in French.
