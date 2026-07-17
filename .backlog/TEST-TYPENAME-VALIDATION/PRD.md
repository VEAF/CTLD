# Lot TEST-TYPENAME-VALIDATION — extend CTLDTypeCollector to cover aiZones and capabilitiesByType typeNames

Status: ⬜ ready
Branch: fix/test-typename-validation → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: [0007 design-time asset validation](../../dev/adr/0007-design-time-asset-validation.md)

## Problem Statement

`CTLDTypeCollector.collect()` (in `src/core/CTLD_typeCollector.lua`) does not cover three sources
of DCS unit typeNames that Mission Makers configure:

1. `aiZones[*].vehicleStock` — keys are DCS unit typeNames (a `{[typeName]=N}` table). This was
   the exact source of the `M1025 HMMWV Armament` bug in `FIX-AI-C2-BUGS` (Bug 2a/2b), which
   caused a silent Leopard-2 spawn due to an invalid typeName falling through unchecked.
2. `capabilitiesByType[*].loadableVehiclesRED` / `loadableVehiclesBLUE` — arrays of DCS unit
   typeNames.
3. `aiZones[*].vehicleTypes` — whitelist arrays of DCS unit typeNames.

The CI linter `tests/ci/unit/config_types_lint_spec.lua` relies exclusively on
`CTLDTypeCollector.collect()` to enumerate all configured typeNames, then cross-checks them against
the vendored datamine set. Because these three sources are absent from the collector, invalid
typeNames in these config areas are **invisible to CI**.

`FIX-AI-C2-BUGS` ticket 03 attempted a runtime check via `Unit.getDescByType()`, but that API does
not exist in DCS Lua — the approach was reverted and ticket 03 marked wontfix pending a
`CTLDTypeCollector` fix. `ASSET-VALIDATION-REVAMP` delivered `CTLDTypeCollector` but did not cover
these three sources. This lot closes that gap.

## Solution

Extend `CTLDTypeCollector.collect()` with three new source blocks (appended after the existing
block 4 for `loadableGroups`). No other file needs to change: the existing CI linter will
automatically catch invalid typeNames in these config areas once the collector knows about them.

## User Stories

- As a **Mission Maker**, I want CI to catch typos or outdated typeNames in `aiZones[*].vehicleStock`
  so that I discover invalid unit types at commit time, not at mission runtime with a silent wrong
  spawn.
- As a **Mission Maker**, I want CI to catch invalid typeNames in
  `capabilitiesByType[*].loadableVehiclesRED/BLUE` so that misconfigured vehicle loadout lists are
  flagged before they reach a live mission.
- As a **Mission Maker**, I want CI to catch invalid typeNames in `aiZones[*].vehicleTypes`
  whitelists so that phantom entries in the whitelist are caught at design time.

## Implementation Decisions

- Extend `CTLDTypeCollector.collect()` only — no changes to the linter, no new modules, no hard-fail.
- For `vehicleStock`: iterate `entry.vehicleStock` **keys** directly (`for typeName, _ in pairs(...)`);
  do NOT call `parseStockTable` — that is a local function in `CTLD_zone.lua` and not available to
  the collector.
- Source label strings to use:
  - `"aiZones[<zoneName>].vehicleStock"`
  - `"capabilitiesByType[<transportType>].loadableVehicles"`
  - `"aiZones[<zoneName>].vehicleTypes"`
- Lenient behavior is preserved: the collector never hard-errors on missing or nil tables, consistent
  with existing source blocks.
- No change to `config_types_lint_spec.lua` is required; it already consumes `result.types` generically.

## Testing Decisions

- Three new `it()` blocks in the existing `describe("collect", ...)` suite in
  `tests/ci/unit/type_collector_spec.lua`, one per new source.
- Each test injects a minimal config table into the collector and asserts that the new typeNames
  appear in `result.types`, following the identical pattern already used by the existing four tests
  in that file.
- No DCS integration scenario is needed — the collector is pure Lua and fully exercisable by busted.

## Out of Scope

- Hard-fail CI on unknown typeNames (the linter already WARNs; escalation is a separate policy
  decision).
- Runtime DCS validation (`Unit.getDescByType` does not exist in DCS Lua — confirmed wontfix in
  `FIX-AI-C2-BUGS` ticket 03).
- Other config sources: `troopTemplates` entries are template names, not DCS typeNames; `loadableGroups`
  is already covered by the existing block 4.

## Further Notes

- The `M1025 HMMWV Armament` incident provides a concrete regression test seed: add a test that
  asserts this exact string would be collected from `vehicleStock` and subsequently flagged by the
  linter as absent from the datamine.
- The lot is self-contained: one `src/` file changed, one test file extended, rebuild required.
