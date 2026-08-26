# FIX-FOB-TROOP-PICKUP — troopPickupAtFOB has no effect in-game

**Status:** ⬜ ready

Found 2026-08-26 while investigating a mission maker question about `troopPickupAtFOB`, then
grilled with the user. Independent of `FEAT-TROOP-ZONE-SCRIPTED-API` (PR #129): that lot lets a
script attach a pickup zone to a named object after the fact; this lot is about a pre-existing,
default-on setting that already promises the same outcome for FOBs specifically and silently
doesn't deliver it.

## Problem Statement

A mission maker who leaves `troopPickupAtFOB` at its default (`true`) — the schema's own words:
"Allow troop pickup at built FOBs" — expects players to be able to embark troops from any FOB
their team builds. Today, nothing happens: the F10 "Load Troops" menu never lists a built FOB as
a pickup point, with no error, no warning, no indication that the setting has no effect. A
mission maker debugging this has no lead — the setting reads as active, the FOB is alive, and the
documentation gives no reason to suspect the setting is disconnected from the feature it names.

## Solution

Wire `troopPickupAtFOB` into the same zone-registration mechanism CTLD already uses for every
other troop pickup point, instead of the currently-dead flag/query-function pair. A deployed FOB
gains a real troop zone, discovered by the F10 menu and the pickup-gating logic exactly like a
Mission-Editor-placed `TRZ_` zone — because, mechanically, it becomes one. Destroying the FOB
removes that zone the same way `_destroyFOB` already removes its logistic zone today.

## User Stories

1. As a mission maker relying on the default `troopPickupAtFOB: true`, I want troops to actually
   be embarkable at any FOB my coalition builds, so that the setting's documented promise is
   true in-game, not just in the schema description.
2. As a mission maker who explicitly sets `troopPickupAtFOB: false`, I want FOBs to grant no troop
   pickup at all, so that I can build FOBs as pure logistics/resupply points without also
   creating an unwanted troop-pickup capability.
3. As a pilot flying a transport near a built FOB, I want the "Load Troops" F10 entry to appear
   the same way it does at any other troop pickup zone, so that I don't need to know FOBs are a
   structurally different case under the hood.
4. As a pilot, I want the FOB's troop-pickup point to disappear the moment the FOB is destroyed,
   so that I never see a "Load Troops" option for a FOB that no longer exists.
5. As a CTLD contributor, I want this fix to reuse the existing `CTLDZoneManager`/`CTLDTroopZone`
   machinery (the same one `TRZ_` zones and `createTroopZoneAtObject` already use), so that FOB
   troop pickup inherits the F10 menu, coalition, and stock logic already tested and working for
   every other troop zone, instead of a second bespoke pickup-gating path.
6. As a CTLD contributor, I want the fix to not remove or break `CTLDFOBManager:isInFOBTroopZone`
   (documented public API, `docs/developer/api-reference.md`), so that an external mission script
   already calling it does not silently start receiving wrong answers.

## Implementation Decisions

- **New `CTLDZoneManager` methods**, placed next to `registerFOBAsLogistic`/`unregisterLogistic`
  in `CTLD_zone.lua` and following their exact style (same logging pattern, same return shape):
  - `registerFOBAsTroopZone(fobName, point, radius, coalitionId)` — synthesizes a `CTLDTroopZone`
    (`name = fobName`, `coalition = coalitionId or 0`, `center = point`, `radius = radius or 150`,
    `active = true`, `pickMaxStock = nil` — unlimited, matching legacy's uncapped FOB pickup — no
    `objectiveFlag`/`objectiveTarget`, no `linkedUnit`: a FOB's position is fixed at its build
    centroid, the same choice `registerFOBAsLogistic` already makes for the same FOB) and stores
    it in `self._troopZones[fobName]`.
  - `unregisterTroopZone(name)` — removes `self._troopZones[name]` if present; a no-op if it
    isn't (covers the `troopPickupAtFOB=false` case, where nothing was ever registered).
- **`CTLDFOBManager:_registerDeployedFOB`** — inside the existing
  `if ctld.gs("troopPickupAtFOB") then ... end` guard: keep the current
  `fob._troopPickup = true` assignment unchanged (so `isInFOBTroopZone` stays truthful for any
  external caller relying on it — User Story 6), and additionally call
  `CTLDZoneManager.getInstance():registerFOBAsTroopZone(fobName, centroid,
  ctld.gs("fobTroopPickupRadius"), coalitionId)`. No new config setting: reuses
  `troopPickupAtFOB` (gate) and `fobTroopPickupRadius` (radius, already 150 by default — matches
  legacy's hardcoded value exactly), both already schema-documented.
- **`CTLDFOBManager:_destroyFOB`** — add
  `CTLDZoneManager.getInstance():unregisterTroopZone(fob.name)` right next to the existing
  `unregisterLogistic(fob.name)` call. Unconditional (safe no-op when nothing was registered).
  This is the FOB's only removal path in `src/` and in legacy alike — no pack/relocate mechanic
  exists for a built FOB in either codebase, so no other cleanup site is needed.
- **No new event published.** `createTroopZoneAtObject` (the other script-driven troop-zone
  constructor) does not publish one either; only `registerFOBAsLogistic` does today
  (`OnLogisticZoneUpdated`), because something already subscribes to it. Adding an unused
  `OnTroopZoneUpdated` here would be speculative — out of scope, tracked separately in
  `dev/roadmap.md` ("Lien générique zone ↔ objet de référence").
- **No legacy `ctld.xxx()` wrapper** — consistent with every `CTLDZoneManager` addition since the
  v2 rewrite.
- **CHANGELOG.md**: a **fix** entry ("restored v1 behavior"), not a change — same framing as
  `FIX-SHIP-ZONE-ANCHOR-PARITY`. No migration note: nothing for a mission maker to do, the old
  (silent no-op) behavior was the bug.

## Testing Decisions

- **Extend the existing seam**, `tests/ci/unit/deploy_managers_spec.lua`'s
  `describe("CTLDFOBManager deploy + destroy" ...)` block (F-012/F-013) — it already calls
  `fm:_registerDeployedFOB(scene(...))` and `fm:_destroyFOB(...)`/`fm:onDead(...)` directly, the
  exact two functions this fix touches. No new test file.
- **Assert on the public consumer path**, not the internal table: use
  `CTLDZoneManager.getInstance():getTroopZoneAtPoint(point, coalition)` — the same method the real
  F10 menu/pickup-gating code calls (`CTLD_zone.lua:1265`) — rather than reaching into
  `_troopZones` directly. Matches the stated philosophy already followed by
  `ship_troop_zone_anchor_spec.lua` and `troop_zone_scripted_api_spec.lua`: assert on public,
  observable behavior.
- **Cases to cover**:
  1. `troopPickupAtFOB = true` (default) — after `_registerDeployedFOB`, `getTroopZoneAtPoint` at
     the FOB's centroid, matching coalition, returns a zone with `hasPickup()` true.
  2. `troopPickupAtFOB = false` — after `_registerDeployedFOB`, `getTroopZoneAtPoint` at the same
     point returns `nil`.
  3. After `_destroyFOB` (or `onDead` driving it below the integrity threshold, reusing the
     existing F-013 setup), `getTroopZoneAtPoint` returns `nil` again — no ghost zone.
  4. `CTLDFOBManager:isInFOBTroopZone` still returns `true`/`false` exactly as before (User Story
     6 — regression guard for the untouched public API).
- **Overriding `ctld.gs` per case**: follow the existing per-test override pattern already used
  across `tests/ci/` (e.g. `ship_troop_zone_anchor_spec.lua`, `aizone_name_collision_spec.lua`) —
  stub in the relevant `it`, restore after.

## Out of Scope

- The generic `linkZonesToOwner`/`unlinkOwner` owner-triggered zone-link mechanism —
  `dev/roadmap.md`, its own future lot. This fix intentionally uses the same narrow, ad hoc
  register/unregister pair the codebase already has for the logistic side, not the generalization.
- FARP troop pickup — FARP has no equivalent setting or mechanic today (verified: no
  `troopPickupAtFARP`, no `isInFARPTroopZone`, nothing). Not part of this bug; a separate feature
  if wanted.
- The "player already standing in the zone gets no menu refresh" gap — pre-existing, affects
  every dynamic zone creation path (`dev/roadmap.md`, "Zones dynamiques — aucun rafraîchissement
  du menu F10"), not specific to this fix.
- Removing or deprecating `CTLDFOBManager:isInFOBTroopZone` / the `fob._troopPickup` flag — kept
  exactly as-is (User Story 6); this fix is additive, not a cleanup of the now-redundant query
  surface.

## Further Notes

- No ADR: this restores a documented, default-on setting to its promised (and legacy-confirmed)
  behavior using a pattern (`registerFOBAsLogistic`/`unregisterLogistic`) the codebase already
  chose for the same FOB on the crate side — not a new architectural decision.
- Direct precedent for shape: `registerFOBAsLogistic`/`unregisterLogistic` (`CTLD_zone.lua`,
  called from `CTLDFOBManager:_registerDeployedFOB`/`_destroyFOB`).
- Legacy reference: `migration/source/CTLD.lua:9676-9677` (sets `ctld.troopPickupAtFOB`-gated
  membership in `ctld.builtFOBS`) and `:10750-10761` (`ctld.inPickupZone`'s FOB fallback branch —
  150 m radius, unlimited stock, coalition-matched).
