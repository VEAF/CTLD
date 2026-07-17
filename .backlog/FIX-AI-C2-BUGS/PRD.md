Status: ⬜ ready

# FIX-AI-C2-BUGS — Fix two bugs in the AI transport C2 (virtual stock) path

## Problem Statement

When an AI transport helicopter lands in a pickup AIZ zone, CTLD executes two sequential
paths:

- **C1** — load a physical DCS vehicle present in the zone (weight-gated).
- **C2** — if C1 did not load, draw a vehicle entry from the zone's virtual stock (Feature T).

Two bugs corrupt this logic:

**Bug 1 — Wrong C2 activation guard.** C2 is gated on `not physicalLoaded`. This flag is
`false` in two distinct cases: (a) no physical vehicle was found at all, and (b) a physical
vehicle was found but rejected by the weight filter. In case (b), C2 activates despite a real
vehicle being present — it silently "loads" a virtual vehicle while the physical one stays
in the zone. The helo then flies to the dropoff zone and spawns a phantom copy. The C2 block
comment already states the intended guard ("only when no physical vehicle found"), so the code
contradicts its own specification.

**Bug 2 — Invalid typeName in virtual stock.** The example vehicleStock in `CTLD_userConfig.lua`
contains `["M1025 HMMWV Armament"] = -1`. This string is not a valid DCS typeName: confirmed
by live injection (`unit:getTypeName()` returns `"Hummer"` for all HMMWV variants, and the DCS
log emits `ERROR woCar: Unit M1025 HMMWV Armament is unknown, replaced with Leopard-2` when C2
tries to spawn it). Two sub-issues: (a) the example config carries an invalid typeName, and
(b) CTLD does not validate vehicleStock keys at zone-load time, so the failure is silent until
a Leopard-2 appears on the battlefield.

Both bugs are exposed end-to-end by the existing MT-08B scenario.

## Solution

**Fix 1 — Correct the C2 guard in `onAILand`.**
Track whether any physical vehicle was found in the zone (before weight filtering) with a
`physicalPresent` boolean declared outside the `if okVS then` block. Set it to `true` when
`#loadables > 0`. Change the C2 guard from `if not physicalLoaded` to
`if not physicalLoaded and not physicalPresent`.

**Fix 2a — Remove the invalid typeName from the example config.**
Delete the `["M1025 HMMWV Armament"] = -1` entry from `CTLD_userConfig.lua` and from every
documentation page that copies this example. `"Hummer"` (stock 3) remains in the zone's
vehicleStock and is sufficient for the test mission.

**Fix 2b — Validate vehicleStock typeNames at zone-load time.**
After `parseStockTable` builds `_aiVehicleStock`, iterate each key and call
`Unit.getDescByType(typeName)`. If it returns nil, log an ERROR and remove the entry. This
makes invalid typeNames fail-fast at mission start rather than silently spawning a Leopard-2
at runtime.

**Regression — MT-08B scenario.**
After all three fixes, `scenario_mt08b_weight_exceeded` (tier `auto-slow`) must reach PASS:
no unexpected spawn at dropoff, physical HMMWV survives in the pickup zone.

## User Stories

1. As a mission maker, I want C2 (virtual stock) to activate only when no physical vehicle is
   present in the pickup zone, so that the weight filter decision (C1 rejection) is final and
   not silently overridden.

2. As a mission maker, I want CTLD to log a clear ERROR at mission start when a vehicleStock
   entry contains an unknown DCS typeName, so that I can fix the config before the mission runs.

3. As a mission maker, I want invalid vehicleStock entries to be skipped rather than passed to
   DCS, so that an unknown typeName never results in a Leopard-2 appearing at a dropoff zone.

4. As a mission maker, I want the example vehicleStock config in `CTLD_userConfig.lua` to use
   only valid DCS typeNames, so that copy-pasting the example produces a working zone.

5. As a developer, I want MT-08B to be a permanent `auto-slow` regression for C2 behavior
   under weight-rejection, so that both bugs cannot regress undetected.

6. As a developer, I want the C2 guard in `onAILand` to match its own comment, so that the
   code is internally consistent and the intent is unambiguous.

## Implementation Decisions

- **Fix 1 scope**: one new local variable `physicalPresent` in `onAILand`, set inside the
  `if okVS then` block when `#loadables > 0` (after type filtering, before weight filtering).
  C2 guard becomes `if not physicalLoaded and not physicalPresent`. No other change to C1 or
  dropoff logic.

- **Fix 2b placement**: validation runs immediately after `parseStockTable` returns the
  `aiVehicleStock` table in `CTLDZoneManager` (zone config parse, DCS init phase). At that
  point DCS APIs are available. Entries with `Unit.getDescByType(typeName) == nil` are
  removed; an ERROR is logged per invalid entry. `isAll` zones bypass this check (no explicit
  type list).

- **Fix 2b scope**: only `vehicleStock` keys are validated. `troopStock` keys are template
  names, not DCS typeNames, and are not in scope.

- **Fix 2a scope**: remove `["M1025 HMMWV Armament"] = -1` from `CTLD_userConfig.lua` and
  the four documentation files that reproduce this example. No other vehicleStock change.

- **MT-08B stays `auto-slow`**: the scenario drives a full AI helo flight (pickup → dropoff)
  and cannot be tier-promoted. It is the definitive end-to-end regression for both fixes.

- **No ADR needed**: the C2 guard fix restores documented intent; the validation strategy
  (fail-fast at load) is the standard CTLD pattern for config errors and is not a novel
  trade-off.

## Testing Decisions

Good tests for these fixes verify observable output (what spawns, what logs, what CTLD
state changes), not internal variable names.

**Bug 1 — C2 guard:**
- L4 regression: `scenario_mt08b_weight_exceeded` (existing). After Fix 1, PASS means:
  `_aiTransportVehicle[unitName]` is nil after pickup (C2 not entered), no unexpected spawn
  at dropoff, physical HMMWV still alive in pickup zone.
- Prior art for L4 scenario structure: `scenario_mt08_ai_vehicle.lua`.

**Bug 2b — typeName validation:**
- L3 (noPlayer) test: configure an AIZ zone with one valid and one invalid vehicleStock entry.
  After zone init, assert the invalid entry is absent from `_aiVehicleStock.current` and that
  a CTLD ERROR was logged. Prior art: `aiTransport_featureT_stockParsing_F176.lua`.

**MT-08B as regression gate:**
- Must remain `auto-slow` in `tests/dcs/pilotPassive/` and pass under
  `run_scenarios.py --tier auto-slow --poll-timeout 900` after all three fixes are applied.

## Out of Scope

- MT-08 (`scenario_mt08_ai_vehicle`): uses a weight override making C1 succeed; C2 is never
  reached. Already PASS 12/12. Not affected.
- MT-14 (`scenario_mt14_ai_aa_system`): AA system path (Feature U), not virtual stock C2.
- T-03b (TOOLING-TEST-TAXONOMY ticket 03b): MT-08 + MT-14 PASS verification. Separate lot.
- Validation of `troopStock` keys: template names, not DCS typeNames.
- `vehicleTypes` whitelist entries: used only for C1 filtering, not for spawning.

## Further Notes

- The priority order in `aiPickVehicleEntry` (stock -1 = `math.huge`) means that an unlimited
  entry (`-1`) always wins over any finite-stock entry. The invalid `"M1025 HMMWV Armament"`
  entry had `-1`, so it was always selected over `"Hummer"` (stock 3) — making the `Hummer`
  virtual stock entry unreachable. After Fix 2a removes it, `"Hummer"` becomes the sole
  virtual stock entry and C2 will correctly pick it.
- The DCS woCar Leopard-2 substitution is silent at the DCS API level (no Lua error, no
  pcall failure). Fix 2b is therefore the only way to surface this class of misconfiguration
  before the mission runs.
