# 02 — `integer` fields in the three bespoke table editors

**Status:** ⬜ ready

**Blocked by:** ticket 01 (reuses the `'integer'` `EditorType` it defines).

## What to build

Mark the relevant fields `'integer'` (via `Field.type`, `tables.ts`) in the three bespoke table
editors' hardcoded field lists — the same mechanism `TROOP_FIELDS` already uses for `'number'` —
and make `RecordListEditor` and each bespoke editor apply the same whole-number step + rounding
behaviour ticket 01 established for `SettingRow`:

- `tables.ts`'s `TROOP_FIELDS` (`loadableGroups`, rendered by `RecordListEditor`): `inf`, `mg`,
  `at`, `aa`, `mortar`, `jtac` become `'integer'` (`name` stays `'string'`, unchanged).
  `RecordListEditor` stops hardcoding `step="0.01"` on every `type:'number'` field and instead
  renders per-field according to `'integer'` vs `'number'`.
- `tables.ts`'s `AIRCRAFT_NUMS` (`capabilitiesByType`, rendered by `AircraftEditor`) is
  restructured from a bare string array into a typed field list (mirroring `TROOP_FIELDS`'s
  shape), so `maxCratesOnboard`, `maxTroopsOnboard` and `maxWholeVehiclesOnboard` become
  `'integer'` while `maxVehicleWeight` stays `'number'`. `AircraftEditor.svelte` renders each
  according to its type instead of treating the whole array as one undifferentiated list.
- `CratesEditor.svelte`'s `cratesRequired` field becomes `'integer'` (`weight`, in the same
  component, stays `'number'` with its existing `step="0.01"` — unchanged).
- `AiZonesEditor.svelte`'s `troopStock`/`vehicleStock` per-template/per-type stock-count field
  becomes `'integer'`.

## Watch out

- `maxVehicleWeight` (in `AIRCRAFT_NUMS`) and `weight` (in `CratesEditor`) are the two continuous
  fields living alongside integer ones in the same array/component — restructuring `AIRCRAFT_NUMS`
  must not accidentally coerce `maxVehicleWeight` to whole-number behaviour.
- `AIRCRAFT_NUMS`'s restructuring changes its exported shape (bare `string[]` → typed field list) —
  check every call site, not only `AircraftEditor.svelte`.

## Acceptance

- Each of the four bespoke locations above renders the whole-number step/rounding behaviour for
  its integer fields, and leaves its one continuous field (`maxVehicleWeight`, `weight`) rendering
  exactly as before.
- `RecordListEditor` no longer applies one blanket `step="0.01"` to every numeric field regardless
  of type.

## Tests

`web/src/lib/*.test.ts` (vitest): `RecordListEditor` (via `loadableGroups`), `AircraftEditor` and
`CratesEditor`/`AiZonesEditor` each apply the whole-number behaviour to their `'integer'`-typed
fields and leave their `'number'`-typed field (`maxVehicleWeight`, `weight`) untouched — same
seam/pattern as this project's existing table-editor tests (e.g. `AiZonesEditor.test.ts`'s
existing indicator tests).
