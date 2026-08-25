# FEAT-TROOP-ZONE-SCRIPTED-API

**Status:** ✅ done

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-parsetrz-visibility-promotion` | ✅ done | 01 — `parseTRZ` promoted to public |
| `02-createtroopzoneatobject` | ✅ done | 02 — `createTroopZoneAtObject` — scripted pickup zone on any named object |
| `03-developer-docs` | ✅ done | 03 — developer docs (EN+FR) |

Program: none — standalone feature, generalizes the FOB-only idea previously sitting in
`dev/roadmap.md` ("FOB — API scriptée pour ajouter une zone de troupes (pickup) par-dessus un
FOB"), grilled and widened to "any named object" (2026-08-26).

## Problem Statement

A mission maker who wants players to embark troops from a FOB, a FARP, a ship, or any other named
object that only exists *after* the mission has loaded has no way to do it. The only
script-callable troop-zone constructor today, `createExtractZone`, can only count an extraction —
it never sets a pickup stock, so it can never produce a "Load Troops" F10 entry. The only
pickup-capable path is a `TRZ_…` zone placed in the Mission Editor and discovered at init, which
cannot target something that doesn't exist yet when CTLD initializes (a scene-built FOB, a spawned
FARP structure, a ship whose logistics only get registered once built).

## Solution

A new public method, `CTLDZoneManager:createTroopZoneAtObject(objectName, trzName)`, callable from
a DO SCRIPT trigger any time after `ctld.initialize()`. `trzName` is a full
`TRZ_<name>_<coalition>_<stock>_<flag>_<target>` string, parsed by the same convention already
documented for editor-placed zones — the mission maker gets identical control over coalition,
pickup stock, extraction flag, and win-target, with no new syntax to learn. `objectName` can name
any DCS entity: a Mission Editor trigger zone, a unit, a static, a group, or an airbase/FARP — the
method resolves whichever kind it is, and anchors the new zone to it when the object is capable of
moving, so the pickup point doesn't go stale if the underlying object does. Tearing the zone down
needs no new function: the existing `removeExtractZone` already clears any troop zone by name,
regardless of how it was created.

## User Stories

1. As a mission maker, I want to call one function with a `TRZ_…` name and the name of an
   already-placed or already-spawned object, so that I can add a troop pickup zone at runtime
   without waiting for the Mission Editor's own zone list.
2. As a mission maker, I want to attach a pickup zone to a FOB built by a scene, so that players
   can embark troops there once it finishes building.
3. As a mission maker, I want to attach a pickup zone to a FARP (an airbase-category object), so
   that players can embark troops there.
4. As a mission maker, I want to attach a pickup zone to a ship or another moving unit, so that
   the pickup point follows it instead of being left behind when it moves.
5. As a mission maker, I want to attach a pickup zone to a Mission Editor trigger zone that
   happens to be a Moving Zone, so that its behavior matches `createExtractZone`'s existing
   zone-anchoring.
6. As a mission maker, I want to attach a pickup zone to a group (e.g. a convoy), so that the zone
   follows the group's lead unit.
7. As a mission maker, I want full control over coalition, pickup stock, extraction flag, and
   win-target through the same `TRZ_…` naming convention I already use for editor-placed zones,
   so that I don't have to learn a second syntax for a dynamically-added one.
8. As a mission maker, I want a clear error logged (and the call to return `false`) when my
   `TRZ_…` name string is malformed, so that I can fix a typo instead of silently getting no zone.
9. As a mission maker, I want a clear error logged (and the call to return `false`) when the named
   object doesn't exist yet (e.g. the FOB isn't built yet), so that I know to delay the call
   rather than debug a silent no-op.
10. As a mission maker, I want the call to refuse (with a warning) and do nothing if I call it
    twice with the same zone name, so that I don't end up with two zones silently overwriting
    each other's state.
11. As a mission maker, I want to remove a zone I created this way using the same
    `removeExtractZone` I already use for extract-only zones, so that I don't need to learn a
    second removal function.
12. As a mission maker, I want a zone attached to an object that has no radius of its own (a
    unit, a static, a group, or an airbase/FARP) to still get a sensible default radius, so that
    I don't have to guess or supply one for the common case.
13. As a developer maintaining CTLD, I want the `TRZ_…` string parser reused (not
    reimplemented) by this new entry point, so that Mission-Editor discovery and the scripted API
    can never silently disagree on what a given `TRZ_…` name means.
14. As a developer maintaining CTLD, I want this feature to reuse the existing `_troopZones`
    table and the F10 menu's existing live-refresh path (no new registry, no new menu code), so
    that a zone created this way behaves identically in-game to one discovered from the Mission
    Editor's zone list.
15. As a CTLD contributor reading the developer docs, I want this method documented in the API
    reference and zones-subsystem pages (EN+FR), next to `createExtractZone` and
    `registerFOBAsLogistic`, so that the three "create a dynamic zone from a script" capabilities
    read together in the one place they're already all documented.

## Implementation Decisions

- **New public method**: `CTLDZoneManager:createTroopZoneAtObject(objectName, trzName)` in
  `src/CTLD_zone.lua`, placed next to `createExtractZone` and following its exact style (return
  `boolean`, `ctld.utils.log` on every outcome).
- **`trzName` parsing**: reuses the existing TRZ_ string parser, **promoted from private
  (`_parseTRZ`) to public (`parseTRZ`)** — a visibility-only rename, no behavior change. Used by
  both Mission-Editor discovery and this new entry point, so the two can never disagree on what a
  `TRZ_…` string means.
- **`objectName` resolution**: a **local helper function** (not a new shared utility in
  `CTLD_utils.lua` — nothing else needs this generality yet) tries, in order: a Mission Editor
  trigger zone, then a unit or static, then a group's first unit, then an airbase. First match
  wins.
- **Conditional anchoring** (applies the project's existing "Anchor"/"Anchored zone" concept to a
  new call site — not a new mechanism):
  - Resolved via a **trigger zone** → the new zone's `dcsName` is set to `objectName`, exactly as
    `createExtractZone` already does — if that zone is a DCS Moving Zone, position tracks it for
    free through the existing `getCenter()` path.
  - Resolved via a **unit, static, or group** → the new zone's `linkedUnit` is set to the
    resolved unit (the group's first unit, if a group) — the zone follows it if it moves, the
    same mechanism already used for a ship-anchored troop zone.
  - Resolved via an **airbase/FARP** → the zone is fixed (airbases don't move, and an airbase is
    never used as `linkedUnit` anywhere in the codebase today).
- **Radius**: a trigger zone's own `.radius` is used directly. For every other resolved kind (no
  radius concept exists for a unit/static/group/airbase, and no radius accessor was found on any
  of them anywhere in this codebase), fall back to a **new, locally-scoped constant** dedicated to
  this function — deliberately not reusing either of the two pre-existing, differing defaults for
  neighboring cases (`CTLDLogisticZone`'s default of 200, `registerFOBAsLogistic`'s default of
  150), which already coexist for unrelated reasons.
- **Removal**: no new function. The existing `removeExtractZone(zoneName)` already clears any
  entry in `_troopZones` by name regardless of how it got there, and needs no change to work for
  zones created by `createTroopZoneAtObject`.
- **Failure handling**, matching `createExtractZone`'s existing pattern exactly: an unparseable
  `trzName`, an unresolvable `objectName`, or a `zoneName` already present in `_troopZones` each
  return `false` and log (`ERROR` for the first two, `WARN` for the collision case) without
  registering anything.
- **No new getter**: the existing `getTroopZone(zoneName)` already reads from `_troopZones` and
  works unchanged for a zone created this way.
- **No legacy `ctld.xxx()` wrapper**: consistent with everything added to `CTLDZoneManager` since
  the v2 rewrite (`registerFOBAsLogistic`, `getLogisticZone`, etc.) — called only as
  `CTLDZoneManager.getInstance():createTroopZoneAtObject(...)`.
- **Documentation**: `createExtractZone` and `registerFOBAsLogistic` are both documented only in
  the **developer** docs (confirmed: neither appears anywhere in `docs/mission-maker/`) —
  `docs/developer/api-reference.md` / `.fr.md` (the flat method-reference table) and
  `docs/developer/subsystems/zones.md` / `.fr.md` (the narrative subsystem page, which also
  carries a short runtime-usage code snippet for each). Added `createTroopZoneAtObject` there,
  next to both, in the same four files.
  Post-review addendum: the mission-maker guide already documents an analogous runtime API for
  logistic zones (`docs/mission-maker/zones.md` § "Deactivating and reactivating a logistic
  zone", `CTLDZoneManager` called directly from a DO SCRIPT) — on explicit request, a matching
  "Creating a pickup zone at runtime" subsection was added to `docs/mission-maker/zones.md` /
  `.fr.md`, right after "Pickup points on ships", with the same `zm:createTroopZoneAtObject(...)`
  / `removeExtractZone(...)` example.
- **Roadmap**: the narrower FOB-only entry in `dev/roadmap.md` this lot generalizes should be
  marked formalized once this lot exists, per the project's own roadmap convention.

## Testing Decisions

- **busted unit tests**, new file `tests/ci/unit/troop_zone_scripted_api_spec.lua`, following the
  exact pattern already used by `tests/ci/unit/ship_troop_zone_anchor_spec.lua` and the beacon
  scripted-API spec: construct the manager via `setmetatable({ _troopZones = {}, ... },
  CTLDZoneManager)` (bypassing the singleton), stub `trigger.misc.getZone` / `Unit.getByName` /
  `StaticObject.getByName` / `Group.getByName` / `Airbase.getByName` per test case in
  `before_each`, restore the originals in `after_each`.
- **Coverage**: each resolution branch (zone, unit, static, group, airbase) produces a zone with
  the right `hasPickup()` / `getCenter()` / radius; an anchored zone actually tracks (mutate the
  fake object's position between two `getCenter()` calls, mirroring
  `ship_troop_zone_anchor_spec.lua`'s own "tracks between two evaluations" test); a malformed
  `trzName` returns `false` and registers nothing; an unresolvable `objectName` returns `false`
  and registers nothing; a duplicate `zoneName` refuses and leaves the first zone untouched;
  `removeExtractZone` tears down a zone created by the new method.
- Good tests here assert on the **public** result — `createTroopZoneAtObject`'s return value and
  the zone's own observable behavior (`hasPickup()`, `getCenter()`, `isInZone()`) — never on
  private internals beyond the `_troopZones` table entry existing, matching how
  `ship_troop_zone_anchor_spec.lua` already asserts.
- A small `tests/dcs` scenario (from `_template_scenario.lua`) confirming the F10 "Load Troops"
  entry actually appears after a live call is recommended to close the loop end-to-end, though the
  existing beacon scripted-API and ship-anchor coverage already exercise the same DCS surface at
  the unit level.

## Out of Scope

- Vehicle-pickup zones (LGZ_-style) attached this way — troops only, matching
  `createExtractZone`'s own troops-only scope.
- A legacy `ctld.xxx()` wrapper.
- A shared, general-purpose "resolve any named DCS object" utility in `CTLD_utils.lua` — the
  resolution chain stays local to `CTLD_zone.lua` until something else actually needs it.
- Changing the two pre-existing, differing default radii (`CTLDLogisticZone`'s 200,
  `registerFOBAsLogistic`'s 150) to align with the new constant — they coexist for unrelated
  reasons and this lot doesn't touch them.
- Confirming whether DCS's `Airbase` class exposes a native radius accessor — not found anywhere
  in this codebase and not verifiable from it; airbases always use the new fallback constant
  regardless.

## Further Notes

- No ADR: this applies the project's existing "Anchor"/"Anchored zone" concept (`CONTEXT.md`) to
  a new call site rather than introducing a new architectural mechanism — grilled explicitly, no
  ADR judged warranted.
- Direct precedent for shape and tests: `createExtractZone`/`removeExtractZone`
  (`src/CTLD_zone.lua`) and the beacon scripted API (`FEAT-VMCT-INTEGRATION` ticket 03,
  `CTLDBeaconManager:createAtPoint()`/`removeBeacon()`).
