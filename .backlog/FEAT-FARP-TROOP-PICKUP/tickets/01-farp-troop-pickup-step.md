# 01 — `troopPickupAtFARP` + final registration step on the 3 FARP scenes

**Status:** ✅ done

See the PRD for the full mechanism and the reasoning behind each choice.

## What changes

1. `CTLD_config_schema.yaml` / `CTLD_config.yaml`, `troops` group, next to `troopPickupAtFOB` /
   `fobTroopPickupRadius`:
   - `troopPickupAtFARP` — boolean, default `true`.
   - `farpTroopPickupRadius` — number, default `150`.
2. `src/scenes/CTLD_farpScene.lua`, `CTLD_farpAlphaScene.lua`, `CTLD_countrysideFarpScene.lua`:
   each gains a new final step (its own step, not merged into an existing message/warehouse step)
   whose `func`:
   - resolves `ab = Airbase.getByName(name)` (`name` = the spawned Heliports-category static's own
     DCS name — already known via `ctx.spawnedObj:getName()` or, for `Countryside FARP`, the
     already-saved `ctx.scene._params.farpName`);
   - if `ctld.gs("troopPickupAtFARP")`, calls `CTLDZoneManager.getInstance():registerFOBAsTroopZone(
     name, point, ctld.gs("farpTroopPickupRadius"), ctx.scene._coalitionId)`;
   - only if that call returned `true` (not refused by the existing collision guard), registers
     `CTLDStaticWatcher.getInstance():watch("trz_farp_" .. name, function() return ab:isExist()
     end, function() CTLDZoneManager.getInstance():unregisterTroopZone(name) end)`.
3. `CHANGELOG.md` `[Unreleased]`: an **Added** entry.
4. `docs/developer/api-reference.md` / `.fr.md`: mention the new settings alongside
   `troopPickupAtFOB` if that table lists them (check the file — it may only list methods, not
   settings; settings could already live in `docs/mission-maker/configuration.md`/`.fr.md` instead
   — verify which file actually carries the settings table before editing the wrong one).
5. `docs/mission-maker/scenes-fob.md` / `.fr.md`: new `## FARP — Forward Arming and Refuelling
   Point` section, symmetric to the existing `## FOB` section (build flow, destruction,
   configuration table), documenting `troopPickupAtFARP`/`farpTroopPickupRadius`.

## Watch out

- **Do not touch `registerFOBAsTroopZone`, `unregisterTroopZone`, or anything in `CTLD_zone.lua`**
  — this ticket is pure reuse. If either needs a change to make this work, that's a signal the PRD
  missed something; stop and re-check rather than patching around it.
- **One step, one concern.** `FARP Alpha` already ends on a completion-message step — the new
  registration logic is its own additional step immediately after, not folded into the existing
  one, matching the FOB scene's own convention (message step, then registration step, kept
  separate).
- The watch must only be registered when `registerFOBAsTroopZone` returns `true`. If it returns
  `false` (name collision — astronomically unlikely for a DCS-assigned airbase name, but the guard
  exists), there is nothing to watch and nothing to clean up.
- `CTLDStaticWatcher` needs no changes and must not be modified — it already self-removes a
  watched entry before firing its callback (verified: `CTLD_core.lua:212-241`).

## Acceptance

- `troopPickupAtFARP = true` (default): after any of the 3 FARP scenes completes, a player-usable
  troop pickup zone exists at the FARP, discovered via the same `CTLDZoneManager` path as a
  Mission-Editor `TRZ_…` zone or a built FOB.
- `troopPickupAtFARP = false`: no zone is registered for that FARP.
- Once DCS considers the FARP destroyed (`Airbase:isExist()` → `false`), the zone is removed — no
  ghost pickup point.
- The F10 "Load from …" entry for a FARP-sourced zone shows the FARP's own name, not a fabricated
  `TRZ_…` prefix (inherited for free from `FIX-FOB-TROOP-PICKUP`'s `displayName` field — no new
  code needed for this, just confirm it holds).
- All three FARP scene variants behave identically.
- `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

- **Structure**: extend `tests/ci/unit/scenes_minefields_spec.lua`'s existing
  `describe("FARP Alpha scene structure (F-043)")` and `describe("farpScene structure (F-091 Part
  1)")` blocks — step count +1, new step is `func`-only with no `registryKey`. Add a new
  `describe("Countryside FARP scene structure")` block (no busted coverage exists for this scene
  today — `dofile` it at `setup()` the same way the other two already are).
- **Behavior**: invoke the new step's `func(ctx)` directly with a hand-built `ctx`, stubbing
  `Airbase.getByName` per test (mirroring `troop_zone_scripted_api_spec.lua`'s stub pattern).
  Assert only through the public `CTLDZoneManager:getTroopZoneAtPoint(point, coalition)` path,
  never by reaching into `_troopZones`. Cases: zone registered when `troopPickupAtFARP=true`; none
  when `false`; zone removed after driving `CTLDStaticWatcher.getInstance():_tick(t)` directly
  (bypassing the real timer) once the stubbed `ab:isExist()` flips to `false`; F10 label shows the
  FARP's own name (same assertion pattern as `menu_gating_spec.lua`'s existing FOB-label test).
- No new test for `CTLDStaticWatcher` itself — reused unchanged.
