# 02 — Migrate MT-08/MT-08B/MT-09 live scenarios from UH-1H to Mi-8MT

**Status:** ✅ done. Mission retype done by a.lingo in the DCS Mission Editor; live re-run
confirmed 2026-09-23 — MT-08 PASS 12/12, MT-08B PASS 7/7, MT-09 PASS 14/14.

Unblocked by an unrelated, pre-existing gap found while diagnosing the first live failure:
`AIZ_depot_B_P_V_10`/`AIZ_depot_B_P_TV_5_10`/`AIZ_livraison_B_D_G` had not been registered by
CTLD (`CTLDZoneManager._troopZones`) since `USERCONFIG-LOADING` (PR #32, 2026-07-17) removed
`CTLD_userConfig.lua` — which declared their `aiZones` entries — from the `CTLD.lua` merge. AIZ_
zones have no naming-convention auto-discovery (confirmed in `docs/mission-maker/zones.md`,
unlike `TRZ_`/`LGZ_`/`WPZ_`), so nothing re-declared them for this dev mission after that lot.
Rather than leave this as a live-session-only workaround, each of the three scenarios now
declares its own required `aiZones` entries defensively (only if not already registered) at the
top of its own step 1 — self-sufficient regardless of whether `CTLD_userConfig.lua` is ever
loaded again for this mission. No `src/` or mission-file change (out of scope for this lot; the
design question is now tracked in `dev/roadmap.md` under "AIZ_ — pourquoi une config
explicite...").

A second, unrelated bug surfaced while re-testing `scenario_mt08b_weight_exceeded.lua`: its first
attempt at excluding "Hummer" from the pickup zone's candidates mutated the wrong config key
(`cfg.settings["loadableVehiclesBLUE"]`, a top-level setting `CTLDVehicleSpawner:_isTypeLoadable`
never reads) instead of `capabilitiesByType.Mi-8MT.loadableVehiclesBLUE` (the field that actually
gates it) — confirmed live by reading both back from the running mission. Fixed to mutate the
correct nested field. Separately, the survival/dropoff checks were rewritten to track the
specific `ATGM-1` unit by name (via CTLD's own vehicle-state record) instead of "any vehicle
found nearby/newly present" — this mission has ground units with `playerCanDrive=true` (real DCS
driving AI) that can wander into either zone over a long test session, producing false
pass/fail unrelated to CTLD's actual behaviour.

## What changes

`missions/Test_CTLDNEXT_01.miz`: the two persistent AI helicopter groups/units retyped in the
Mission Editor (not scripted — the editor resets livery/payload to a valid Mi-8MT default itself):

| Group/unit name (unchanged) | Old type | New type | Used by |
|---|---|---|---|
| `heliai_vehicle` | `UH-1H` | `Mi-8MT` | MT-08, MT-08B |
| `heliai_full` | `UH-1H` | `Mi-8MT` | MT-09 |

`tests/dcs/pilotPassive/scenario_mt08_ai_vehicle.lua`: header comments updated to `Mi-8MT`; the
Hummer-weight override comment corrected (no longer "above the limit", just defensively pinned
low — see ticket 01's PRD notes); step 1 now defensively registers `AIZ_depot_B_P_V_10`/
`AIZ_livraison_B_D_G` in `aiZones` if not already present (see above).

`tests/dcs/pilotPassive/scenario_mt09_ai_full_cycle.lua`: header comment updated to `Mi-8MT`; step
1 defensively registers `AIZ_depot_B_P_TV_5_10`/`AIZ_livraison_B_D_G`. No other logic change —
`MT-09.1.9`'s `canTransportWholeVehicle` check and the TV-pickup detection both already read the
transport's real type dynamically (`unit:getTypeName()`), not a hardcoded `"UH-1H"`.

`tests/dcs/pilotPassive/scenario_mt08b_weight_exceeded.lua`: target vehicle switched from
"Hummer" to the pre-existing `ATGM-1` unit (type `M1045 HMMWV TOW`, 5000 kg); capability lookup
key `"UH-1H"` → `"Mi-8MT"`; weight-table key `"Hummer"` → `"M1045 HMMWV TOW"`; step 1 defensively
registers `AIZ_depot_B_P_V_10`. `"Hummer"` temporarily removed from
`capabilitiesByType.Mi-8MT.loadableVehiclesBLUE` for the scenario's duration (restored in
`cleanup()`) so the Hummers sharing the pickup zone don't get picked up instead and mask the
weight-rejection path. The survival check (`MT-08B.2.3`) and dropoff check (`MT-08B.3.1`) now
track the `ATGM-1` unit specifically (by name, via CTLD's own vehicle-state record) instead of
"any vehicle found nearby" / "any new unit in the zone" — the now-unused generic
`snapshotGroundUnitsInZone`/`newUnitsVsSnapshot` helpers are removed.

## Watch out

- `scenario_mt08b_weight_exceeded.lua`'s pickup zone (`AIZ_depot_B_P_V_10`) physically contains
  both the Hummer cluster (MT-08's own vehicles) and `ATGM-1`, ~30 m apart. Without the
  `loadableVehiclesBLUE` exclusion, Mi-8MT's realistic 3000 kg cap would let it load a Hummer
  (2400 kg, now under the cap) instead of correctly rejecting `ATGM-1` (5000 kg) — CTLD would be
  behaving correctly, but the scenario would no longer be testing what it claims to test.
- `C-130J-30`, `76MD`, `Hercules` (the other `canTransportWholeVehicle: true` survivors) are
  fixed-wing — a different DCS group category from the existing helicopter groups. They cannot
  be substituted here without restructuring the mission's group category, which is out of scope.
- The retype was done directly in the Mission Editor, not scripted against the raw `mission` Lua
  table — deliberately, so livery/payload land on valid Mi-8MT defaults rather than stale
  UH-1H-specific values (a prior inspection of the `.miz` found a UH-1H-only livery
  (`italy 15b stormo s.a.r -soccorso`) and an `AddPropAircraft` block that do not carry over
  cleanly to a different airframe by a blind string swap).
- This mission has ground units with `playerCanDrive=true` (real DCS driving AI) that can wander
  into either zone over a long test session, independent of anything CTLD does — a check that
  looks for "any vehicle nearby" or "any new unit in the zone" will eventually produce a false
  pass or fail from this traffic alone. Track the specific unit by name instead (see `MT-08B.2.3`/
  `.3.1` above) for any future check of this shape.
- Stopping the local Python runner (`run_scenarios.py`) does **not** stop a scenario already
  injected into DCS — the HTTP request already returned, and the Lua script keeps running inside
  the mission independently. Two live re-runs collided this way during this lot's validation
  (both instances spawning/destroying a clone under the same name, `heliai_vehicle_run`), which
  looked like a Mi-8MT "disappearing" mid-flight. A mission reload is the only reliable way to
  guarantee no orphaned scenario is still running before a fresh injection.

## Acceptance

- MT-08 (`scenario_mt08_ai_vehicle.lua`): AI Mi-8MT picks up the weight-overridden Hummer at
  `AIZ_depot_B_P_V_10` and drops it at `AIZ_livraison_B_D_G` — unchanged pass criteria.
- MT-08B (`scenario_mt08b_weight_exceeded.lua`): `MT-08B.1.1`/`.1.2` confirm the weight mismatch
  against `Mi-8MT`/`M1045 HMMWV TOW`; `MT-08B.2.1`–`.2.3` confirm C1 rejects `ATGM-1` and it
  survives in the zone; `MT-08B.3.1` confirms no unexpected spawn at dropoff.
- MT-09 (`scenario_mt09_ai_full_cycle.lua`): `MT-09.1.9` confirms
  `capabilitiesByType.Mi-8MT.canTransportWholeVehicle == true`; `MT-09.2.1`/`.3.1`/`.3.2` pass via
  troops and/or vehicle pickup — no regression from the type change.

## Tests

Live DCS only (tier `auto-slow`) — no busted seam for a DCS-injected AI-flight scenario. Run via
the project's `dcs-bridge`/`run_scenarios.py` injection loop against `Test_CTLDNEXT_01.miz`, per
`feedback_dcs-test-before-pr`: validated live before the PR opens.
