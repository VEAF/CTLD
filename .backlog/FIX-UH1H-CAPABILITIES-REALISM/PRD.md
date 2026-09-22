# FIX-UH1H-CAPABILITIES-REALISM — UH-1H whole-vehicle transport is unrealistic and contradicts the docs

**Status:** in-progress.

Requested by **a.lingo**, 2026-09-22/23: the UH-1H's default `capabilitiesByType` entry in
`src/CTLD_config.yaml` claims `canTransportWholeVehicle: true` and `maxTroopsOnboard: 8`. Neither
matches the airframe. A Huey has no internal cargo bay for a whole ground vehicle, and its real
troop capacity is closer to 10 than 8.

## Problem Statement

`src/CTLD_config.yaml`'s `UH-1H` entry says the aircraft can carry a whole ground vehicle
(`canTransportWholeVehicle: true`). This is not just an unrealistic default: the published
documentation already contradicts it —
[docs/pilot/vehicles.md:8-11](../../docs/pilot/vehicles.md#L8) states *"Everything else —
including the UH-1H — moves vehicles the crate way instead"*, i.e. it explicitly describes the
UH-1H as **not** whole-vehicle capable. The config and the docs disagree, and the docs are the
one describing the intended behaviour. Separately, `maxTroopsOnboard: 8` undersells the type's
real troop capacity.

## Solution

Set `capabilitiesByType.UH-1H.canTransportWholeVehicle = false` (aligning the config with the
docs) and `maxTroopsOnboard = 10` in `src/CTLD_config.yaml`. This is a **deliberate legacy-parity
deviation** — `migration/source/CTLD.lua:1824` hardcodes the UH-1H troop limit at 8 — made
explicitly at the mission maker's request for realism, not a bug fix.

Turning `canTransportWholeVehicle` off for the only helicopter that had it removes the sole
airframe two live DCS integration scenarios (MT-08, MT-08B, MT-09) use to exercise AI whole-vehicle
pickup/dropoff. They are migrated to `Mi-8MT`, the only other helicopter-category type in
`capabilitiesByType` (the three other `canTransportWholeVehicle: true` survivors — `C-130J-30`,
`76MD`, `Hercules` — are fixed-wing, a different DCS group category, and cannot simply be retyped
into a helicopter group). `Mi-8MT`'s own entry had `canTransportWholeVehicle: true` set but was
**not actually functional**: `maxWholeVehiclesOnboard: 0` and no `loadableVehiclesBLUE/RED` or
`maxVehicleWeight` meant it could never load a vehicle in practice. This lot completes it with
realistic values (external sling-load rating ≈ 3000 kg, not the 13000 kg MTOW) so the migrated
scenarios exercise real behaviour, not a coincidental pass.

## User Stories

1. As a mission maker who read the pilot documentation, I want the UH-1H's actual capabilities to
   match what the docs already describe, so that I am not misled into briefing a whole-vehicle
   pickup a Huey cannot perform.
2. As a mission maker aiming for realism, I want the UH-1H's troop capacity to reflect the real
   airframe (10, not 8), so that my missions are not artificially constrained.
3. As a mission maker using a Mi-8MT for logistics, I want it to be able to carry a whole ground
   vehicle within a realistic weight limit, so that the capability advertised by
   `canTransportWholeVehicle: true` is not a dead flag.
4. As a developer running the live DCS regression suite, I want MT-08/MT-08B/MT-09 to keep
   exercising the AI whole-vehicle pickup/dropoff path after the UH-1H default changes, so that
   this capability is not silently left untested.
5. As a developer reading `scenario_mt08b_weight_exceeded.lua`, I want the weight-rejection
   diagnostic to actually test weight rejection (not accidentally succeed by loading a different,
   lighter vehicle sharing the same pickup zone), so that the test's pass/fail is meaningful.

## Implementation Decisions

- `capabilitiesByType.UH-1H`: `canTransportWholeVehicle` → `false`, `maxTroopsOnboard` → `10`.
  `loadableVehiclesBLUE/RED`, `maxVehicleWeight` and `maxWholeVehiclesOnboard` are left in place
  (inert but harmless while the capability is off) — matching the existing precedent of
  `CH-47Fbl1`, which already carries the same fields with `canTransportWholeVehicle: false`.
- `capabilitiesByType.Mi-8MT`: added `maxVehicleWeight: 3000` (real external sling-load rating,
  not the 13000 kg MTOW the requester initially proposed — MTOW is the airframe's own total
  takeoff weight, not its cargo lift capacity; every other helicopter/aircraft entry in this table
  already uses a lift-capacity figure, not MTOW), `loadableVehiclesBLUE`/`loadableVehiclesRED`
  (same lists as `UH-1H`), and `maxWholeVehiclesOnboard` raised from `0` to `1`. `maxTroopsOnboard`
  (16) and `canParachuteDrop` (false) are untouched — out of scope, not part of this request.
- Live DCS test migration (`tests/dcs/pilotPassive/`): the two persistent AI helicopter
  groups/units in `missions/Test_CTLDNEXT_01.miz` — `heliai_full` (used by MT-09) and
  `heliai_vehicle` (used by MT-08 and MT-08B) — are retyped from `UH-1H` to `Mi-8MT` directly in
  the DCS Mission Editor (livery/payload reset by the editor itself; not scripted, to avoid
  hand-editing stale UH-1H-specific fields — the editor already knows how to produce a valid
  Mi-8MT unit record). No new unit added to the mission.
- `scenario_mt08b_weight_exceeded.lua`'s target vehicle changes from the "Hummer" units
  (2400 kg — now *under* Mi-8MT's realistic 3000 kg cap, so no longer over-weight) to the
  pre-existing `ATGM-1` unit (type `M1045 HMMWV TOW`, 5000 kg, already positioned ~30 m from the
  same units the Hummers occupy). Because the Hummers physically share the same pickup zone as
  ATGM-1, and are now weight-compatible with Mi-8MT, the scenario temporarily removes `"Hummer"`
  from `loadableVehiclesBLUE` for its own duration (restored in `cleanup()`) so the *type* filter,
  not weight, keeps the Hummers out of contention — otherwise CTLD would correctly load a Hummer
  instead of rejecting ATGM-1, which is correct engine behaviour but defeats this scenario's
  specific diagnostic purpose. `scenario_mt08_ai_vehicle.lua`'s own Hummer-weight override (down to
  1100 kg, for its unrelated happy-path pickup/dropoff test) is left in place — still harmless,
  now redundant since 2400 kg already clears Mi-8MT's 3000 kg cap, but pinning it low keeps that
  scenario's success independent of whichever aircraft type `heliai_vehicle` carries.

## Testing Decisions

- `tests/ci/data/config_defaults.json` (the `ctld-tools gen` oracle `config_spec.lua` diffs
  against) regenerated from the edited `src/CTLD_config.yaml` —
  `poetry run ctld-tools gen --yaml src/CTLD_config.yaml --out tests/ci/data/config_defaults.json`.
- `src/CTLD_config_default_yaml.lua` (the embedded `ctld.configDefault` string) regenerated via
  the standard build (`tools/build/merge_CTLD.ps1`, which calls `ctld-tools embed`).
- `tests/ci/unit/player_spec.lua`'s `CTLDPlayerManager _detectCapabilities` cases for `UH-1H`
  hard-coded the old default (`canCarryVehicles == true`, from real config, not a stub) — flipped
  to `is_false` with the comment corrected. Prior art for this seam: the same `describe` block's
  `SK-60`/`Hercules` cases, which already assert against the real default config the same way.
  Every other reference to `UH-1H`/`maxTroopsOnboard`/`canTransportWholeVehicle` found across
  `tests/ci/` (troop/parachute/vehicle functional specs) stubs `ctld.gs` directly with its own
  literal capability table, independent of the real default — confirmed unaffected, not touched.
- No new unit test added for `Mi-8MT`'s completed whole-vehicle fields: `config_spec.lua`'s
  oracle diff already covers presence/shape of every `capabilitiesByType` entry generically.
- Live DCS (`tests/dcs/pilotPassive/`, tier `auto-slow`): `scenario_mt08_ai_vehicle.lua`,
  `scenario_mt08b_weight_exceeded.lua`, `scenario_mt09_ai_full_cycle.lua` re-run against
  `missions/Test_CTLDNEXT_01.miz` after the mission retype, per
  `feedback_dcs-test-before-pr` — validated live before the PR opens, not after.

## Out of Scope

- Any other `capabilitiesByType` entry besides `UH-1H` and `Mi-8MT`.
- `Mi-8MT.maxTroopsOnboard` / `canParachuteDrop` — not part of the request, left untouched.
- Removing the now-redundant Hummer-weight override in `scenario_mt08_ai_vehicle.lua` — harmless,
  left in place rather than trimmed opportunistically.
- Closing the general "aircraft category mismatch" gap (fixed-wing types cannot replace a
  helicopter group, and vice versa) — noted here as a fact about this migration, not a mechanism
  to build.

## Further Notes

- No ADR: this is a data-only default change plus a live-test asset fix-up, not a new mechanism
  or an architectural decision.
- `groundVehicleWeights` (`src/CTLD_config.yaml`) only carries five DCS types with a non-zero
  weight (`BTR_D`, `Hummer`, `BRDM-2`, `M1045 HMMWV TOW`, `M1043 HMMWV Armament`) — any vehicle
  type absent from this table defaults to weight `0` and is therefore always "compatible",
  regardless of `maxVehicleWeight`. Worth knowing before picking a future weight-diagnostic target.
