# 01 — `registerFOBAsTroopZone`/`unregisterTroopZone` + FOB wiring

**Status:** ✅ done

See the PRD for the legacy reference behaviour and the full rationale.

## What changes

1. `CTLDZoneManager` (`CTLD_zone.lua`), next to `registerFOBAsLogistic`/`unregisterLogistic`:
   - `registerFOBAsTroopZone(fobName, point, radius, coalitionId)` — synthesizes a
     `CTLDTroopZone` (`name = fobName`, `coalition = coalitionId or 0`, `center = point`,
     `radius = radius or 150`, `active = true`, `pickMaxStock = 0` — unlimited, per
     `CTLDTroopZone:consumeStock`'s own convention — no `objectiveFlag`/`objectiveTarget`, no
     `linkedUnit`) and stores it in `self._troopZones[fobName]`.
   - `unregisterTroopZone(name)` — removes `self._troopZones[name]` if present, no-op otherwise.
2. `CTLDFOBManager:_registerDeployedFOB` (`CTLD_fob.lua`): inside the existing
   `if ctld.gs("troopPickupAtFOB") then` guard, keep `fob._troopPickup = true` and add a call to
   `CTLDZoneManager.getInstance():registerFOBAsTroopZone(fobName, centroid,
   ctld.gs("fobTroopPickupRadius"), coalitionId)`.
3. `CTLDFOBManager:_destroyFOB` (`CTLD_fob.lua`): add
   `CTLDZoneManager.getInstance():unregisterTroopZone(fob.name)` next to the existing
   `unregisterLogistic(fob.name)` call.
4. `CHANGELOG.md` `[Unreleased]`: a **fix** entry ("restored v1 behaviour: troops can now be
   picked up at a built FOB when `troopPickupAtFOB` is true"), no migration note.
5. Developer docs — `docs/developer/api-reference.md` / `.fr.md` and
   `docs/developer/subsystems/zones.md` / `.fr.md`: document `registerFOBAsTroopZone`/
   `unregisterTroopZone` next to the existing `registerFOBAsLogistic`/`unregisterLogistic`
   entries, same four files, same pattern.

## Watch out

- Do **not** touch `CTLDFOBManager:isInFOBTroopZone` or remove `fob._troopPickup` — both stay
  exactly as-is (documented public API, PRD User Story 6). This fix is additive.
- `unregisterTroopZone` must be safe to call even when `troopPickupAtFOB` was `false` at deploy
  time (nothing registered) — `_destroyFOB` calls it unconditionally.
- `registerFOBAsTroopZone` takes no `linkedUnit` — a FOB's position is fixed at its build
  centroid, matching `registerFOBAsLogistic`'s own choice for the same FOB. Don't reintroduce
  anchoring here; that's a different (unrelated) concern.

## Acceptance

- `troopPickupAtFOB = true` (default): after a FOB deploys, `CTLDZoneManager:getTroopZoneAtPoint`
  at the FOB's centroid, matching coalition, returns a zone with `hasPickup()` true.
- `troopPickupAtFOB = false`: after the same deploy, `getTroopZoneAtPoint` at that point returns
  `nil`.
- After the FOB is destroyed (integrity below threshold), `getTroopZoneAtPoint` at its former
  centroid returns `nil` again — no ghost zone.
- `CTLDFOBManager:isInFOBTroopZone` behaves exactly as before (unchanged regression guard).
- `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

Extend `tests/ci/unit/deploy_managers_spec.lua`'s `describe("CTLDFOBManager deploy + destroy" ...)`
block (F-012/F-013 — already calls `_registerDeployedFOB`/`_destroyFOB`/`onDead` directly). Assert
via the public `CTLDZoneManager.getInstance():getTroopZoneAtPoint(point, coalition)` path, not by
reaching into `_troopZones` directly (matches `ship_troop_zone_anchor_spec.lua`'s philosophy).

- `troopPickupAtFOB = true` → `getTroopZoneAtPoint` at the FOB centroid returns a zone,
  `hasPickup()` true.
- `troopPickupAtFOB = false` → `getTroopZoneAtPoint` at the same point returns `nil`.
- After `_destroyFOB` (or `onDead` driving it below threshold, reusing the existing F-013 setup),
  `getTroopZoneAtPoint` returns `nil`.
- `isInFOBTroopZone` unchanged: still `true`/`false` exactly as before this ticket, for both
  `troopPickupAtFOB` values (regression guard on the untouched public API).
