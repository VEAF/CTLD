# 01 — Extend CTLDTypeCollector to cover vehicleStock, loadableVehicles, vehicleTypes

Status: ⬜ ready
Type: AFK
Repo: CTLD
GitHub: #35

## What to build

Extend `CTLDTypeCollector.collect()` in `src/core/CTLD_typeCollector.lua` with three new source
blocks (appended after the existing block 4 for `loadableGroups`):

1. **`aiZones[*].vehicleStock` keys** — iterate `entry.vehicleStock` keys directly
   (`for typeName, _ in pairs(...)`) as the table is `{[typeName]=N}`; do NOT call
   `parseStockTable` (local to `CTLD_zone.lua`). Source label:
   `"aiZones[<zoneName>].vehicleStock"`.
2. **`capabilitiesByType[*].loadableVehiclesRED` / `loadableVehiclesBLUE`** — iterate both arrays.
   Source label: `"capabilitiesByType[<transportType>].loadableVehicles"`.
3. **`aiZones[*].vehicleTypes`** — iterate the whitelist array. Source label:
   `"aiZones[<zoneName>].vehicleTypes"`.

No other file needs to change: `config_types_lint_spec.lua` already consumes `result.types`
generically and will automatically catch invalid typeNames in these config areas once the collector
is extended.

Add three `it()` blocks in the existing `describe("collect", ...)` suite in
`tests/ci/unit/type_collector_spec.lua`, one per new source, following the pattern of the four
existing tests. Include a regression seed for the `M1025 HMMWV Armament` incident in the
`vehicleStock` test.

Rebuild `CTLD.lua` after the `src/` change.

## Acceptance criteria

- [ ] `CTLDTypeCollector.collect()` collects typeNames from `aiZones[*].vehicleStock` keys.
- [ ] `CTLDTypeCollector.collect()` collects typeNames from `capabilitiesByType[*].loadableVehiclesRED` and `loadableVehiclesBLUE`.
- [ ] `CTLDTypeCollector.collect()` collects typeNames from `aiZones[*].vehicleTypes`.
- [ ] Three new `it()` tests in `type_collector_spec.lua`; all pass under busted.
- [ ] `vehicleStock` test includes `"M1025 HMMWV Armament"` as a regression seed.
- [ ] Lenient behavior preserved: no hard-error on missing/nil tables.
- [ ] `CTLD.lua` rebuilt; Lua 5.1; luacheck clean; `busted tests/ci/` green.

## Blocked by

None.
