# 02 — Anchor-death real removal for troop zones (ADR 0021)

**Status:** ✅ done

**Blocked by:** [01](01-dynamic-zone-menu-refresh.md) — removal must publish the troop-zone event
ticket 01 introduces, so a player standing in a zone whose anchor just died sees it disappear
immediately, not just on their next takeoff/landing.

## What to build

Fix the existing asymmetry: a `linkedUnit`-anchored **logistic** zone is already actually removed
when its anchor dies (`CTLDZoneManager:onDead`, `S_EVENT_DEAD`, direct unit-name key lookup). The
equivalent **troop** zone (a ship or ground vehicle anchored via `createTroopZoneAtObject`) is
never removed today — it freezes at the wreck and stays fully usable forever. Per **ADR 0021**,
unify on real removal (the zone's name freed) for troop zones too, using whichever detection
mechanism DCS actually makes reliable for the anchor's object kind:

- **Unit/group anchor**: extend `CTLDZoneManager:onDead` to also scan `_troopZones` for an entry
  whose `_linkedUnit` or `_anchorUnitName` matches the dead unit (the existing handler only checks
  `_logisticZones` by a direct unit-name-as-key lookup, which doesn't apply here — a troop zone is
  keyed by its `zoneName`, not by its anchor's name). On a match, remove the entry and publish the
  troop-zone-update event from ticket 01 with a removal reason.
- **Static anchor**: wire `CTLDStaticWatcher:watch(...)` into `createTroopZoneAtObject` at creation
  time whenever the resolved anchor is a static (`isExist()` polling) — `S_EVENT_DEAD` is
  documented unreliable for statics elsewhere in this codebase. The watch callback removes the zone
  by its actual `zoneName` (closure capture) and publishes the same event, mirroring the existing
  FARP troop-pickup path exactly.
- This applies **retroactively**: every existing `linkedUnit`-anchored troop zone (ship, ground
  vehicle via `createTroopZoneAtObject`) and a Mission-Editor Moving-Zone-anchored `TRZ_` (its
  `_anchorUnitName` is already populated at discovery) gains real removal, not only zones created by
  the future auto-discovery path (ticket 03).

## Watch out

- Do not touch the existing `_logisticZones` branch of `onDead` — it already works correctly; this
  ticket only adds the missing `_troopZones` branch alongside it.
- Do not build a new generic "zone ↔ anchor" registry or refactor the FARP path's own
  `CTLDStaticWatcher` usage — reuse it as-is, following its existing call shape
  (`watch(id, checkFn, onDeadFn, meta)`), same as `FEAT-FARP-TROOP-PICKUP` did.
- A zone with **no** anchor (a fixed-position `TRZ_`, or one resolved via an airbase/FARP) is
  unaffected — `isAlive()` already returns `true` unconditionally for those; don't add any watch
  for them.
- Watch-key namespacing: pick an id that can't collide with the FARP path's own
  `"trz_farp_" .. name` keys in the same shared `CTLDStaticWatcher` registry (that watcher already
  logs a collision `WARN` if two callers reuse the same id — verify no collision, don't rely on the
  warning to catch it after the fact).
- This is a **behavior change** for a zone that exists today (ship/truck): document it as a
  `CHANGELOG.md` `[Unreleased]` entry (Fixed, not Added) — see ticket 04 for the doc/changelog pass,
  but don't skip flagging it here if you land this ticket standalone.

## Acceptance

- A troop zone anchored to a unit or group (`createTroopZoneAtObject`, or a Mission-Editor Moving
  Zone) is removed from `_troopZones` when its anchor dies (`S_EVENT_DEAD`), and its name becomes
  immediately reusable by a new `TRZ_` registration.
- A troop zone anchored to a static is removed once `CTLDStaticWatcher` detects `isExist() == false`
  on its next tick.
- A player standing in a zone at the moment its anchor dies sees the corresponding F10 entries
  disappear (via ticket 01's refresh), not on their next takeoff/landing.
- A fixed-position or airbase/FARP-anchored troop zone is unaffected — no watch registered, no
  removal.
- The existing FARP-sourced troop zone removal path (`registerFOBAsTroopZone`/`unregisterTroopZone`
  via `CTLDStaticWatcher`) is unchanged and still passes its existing tests.

## Tests

- Extend `troop_zone_scripted_api_spec.lua` (or a new zone-lifecycle spec): a unit/group-anchored
  zone is removed after a simulated `S_EVENT_DEAD` for its anchor — assert `getTroopZone(name)`
  returns `nil` afterward, and that the ticket-01 event fired.
- A static-anchored zone case driven by advancing `CTLDStaticWatcher:_tick()` directly (bypassing
  the real timer — the same technique `FEAT-FARP-TROOP-PICKUP`'s own tests use) after stubbing
  `isExist()` to `false`.
- **Regression case**: a ship- or truck-anchored zone created via `createTroopZoneAtObject` (mirror
  `ship_troop_zone_anchor_spec.lua`'s existing fixture) — today's "frozen, `isAlive() == false` but
  still queryable" behavior must become "removed" once this ticket ships; update or add to that spec
  file accordingly rather than leaving a stale assertion behind.
- Only external, public behavior asserted (`getTroopZone` result, menu content) — no reaching into
  `_troopZones` internals beyond confirming the entry is gone.
