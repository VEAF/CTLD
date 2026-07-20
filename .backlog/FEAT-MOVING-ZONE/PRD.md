Status: ready

# PRD — FEAT-MOVING-ZONE: Anchored zones via DCS Moving Zone

## Problem Statement

A Mission Maker can attach a DCS trigger zone to a moving unit in the Mission Editor (Moving Zone
feature). In-game, the zone follows the unit. However, CTLD snapshots zone positions at init from
`env.mission.triggers.zones` and never updates them. A LGZ_ or TRZ_ attached to a vehicle or ship
would behave as a fixed zone at its initial position — defeating the intent of the MM who placed a
Moving Zone.

The existing `logisticUnits` legacy mechanism already solves this for logistic zones, but it
requires explicit config and is not available for troop zones, AI-transport zones, or waypoint
zones. MMs have no way to attach a CTLD zone to a moving unit using only the ME naming convention.

## Solution

CTLD resolves zone positions lazily via `trigger.misc.getZone()` instead of snapshotting them at
init. For zones attached to a unit (Moving Zones), this DCS API returns the live position of the
anchor each time it is called. For fixed zones, it returns the same fixed position — so the
behavior is transparent and fully backward-compatible.

When an anchored zone's unit is destroyed, CTLD marks the zone inactive (`isAlive()` returns false)
and stops evaluating it.

Polygon Moving Zones are fully supported: CTLD stores the relative vertex offsets at init and
reconstructs absolute polygon vertex positions from the live center at runtime.

## User Stories

1. As a MM, I want to attach a LGZ_ zone to a ship or vehicle in the ME so that the logistic zone
   follows the unit in flight, without editing any CTLD config file.
2. As a MM, I want to attach a TRZ_ zone to a moving ground unit so that the troop pickup/dropoff
   zone moves with it dynamically.
3. As a MM, I want to attach an AIZ_ zone to a moving unit so that the AI-transport auto-pickup
   area follows the unit.
4. As a MM, I want to attach a WPZ_ zone to a moving unit so that the waypoint zone follows the
   unit.
5. As a MM, I want a circular Moving Zone to work without any naming convention change — the LGZ_
   or TRZ_ prefix is sufficient.
6. As a MM, I want a polygon Moving Zone to preserve its shape as it moves, not just its center,
   so that troops or crates are accurately gated by the polygon boundary.
7. As a MM, I want the zone to become inactive if its anchor unit is destroyed, so that players
   cannot interact with a zone whose reference point no longer exists.
8. As a MM, I want existing fixed zones to behave exactly as before, so that this feature
   introduces zero regression for missions not using Moving Zones.
9. As a MM, I want the zone's liveness to be evaluated at every interaction, so that a unit
   destroyed mid-mission immediately deactivates the zone without a restart.
10. As a MM, I want the `logisticUnits` config mechanism to keep working unchanged, so that
    missions using the legacy dynamic-zone config are not affected.
11. As a developer, I want all zone types to expose a consistent `getCenter()` method, so that
    callers never access `zone.center` directly and the dynamic/static distinction is encapsulated.
12. As a developer, I want `isDynamic()` to return true for any anchored zone (Moving Zone or
    legacy linkedUnit), so that callers can check dynamism without knowing the anchor mechanism.
13. As a developer, I want `isAlive()` to return false when the anchor unit is dead, so that zone
    scheduler loops can skip inactive anchored zones without special-casing.

## Implementation Decisions

- **`getCenter()` is the single position accessor for all zone types.** `CTLDTroopZone` currently
  lacks `getCenter()` and callers access `zone.center` directly. This lot adds `getCenter()` to
  `CTLDTroopZone` and migrates all direct `zone.center` accesses throughout `src/` to
  `zone:getCenter()`.

- **`trigger.misc.getZone(name)` replaces the snapshot in `getCenter()`.** Called on every
  invocation. No cache — CTLD loop cadence (~1 s) makes the cost negligible. Fallback to
  `self._center` if the API returns nil.
  Priority order in `getCenter()`:
  1. `self._linkedUnit:getPoint()` (legacy logisticUnits — unchanged)
  2. `trigger.misc.getZone(self._dcsZoneName).point` (Moving Zone or fixed zone)
  3. `self._center` (static fallback)

- **Moving Zone auto-detection at init.** At zone discovery time, CTLD reads `zd.linkUnit` from
  `env.mission.triggers.zones`. If present and non-nil, the zone is anchored. CTLD resolves the
  unit name by iterating `coalition.getGroups()` at discovery time (lazy, one pass per zone with
  a linkUnit). The unit name is stored as `_anchorUnitName`.

- **`isAlive()` extended to cover anchored zones.** If `_anchorUnitName` is set,
  `isAlive()` returns `Unit.getByName(_anchorUnitName) ~= nil` (and `:isExist()`). When the anchor
  is destroyed, DCS returns a garbage position (relative offset from world origin, not nil and not
  last known position — confirmed by live test). The `isAlive()` guard prevents the zone from being
  evaluated in that state.

- **`isDynamic()` unified.** Returns true if `_linkedUnit ~= nil` OR `_anchorUnitName ~= nil`.
  No caller needs to distinguish the two anchor mechanisms.

- **Polygon Moving Zones: relative-offset storage.** `env.mission.triggers.zones` stores polygon
  vertices as offsets relative to the anchor unit for Moving Zones (confirmed by live test:
  `type=2`, small-valued coordinates). `trigger.misc.getZone()` does not return vertices — only
  center + enclosing radius. CTLD stores the relative offsets at init; `isInZone()` reconstructs
  absolute vertex positions as `center_live + offset` on each call and feeds the existing raycast.
  For static polygon zones, vertices from `env.mission` are already absolute — stored and used
  as-is (existing behavior, unchanged).

- **Backward compatibility is transparent.** `trigger.misc.getZone()` returns the fixed position
  for static zones — no behavioral difference. Missions not using Moving Zones require no change.

- **`CTLDZoneManager` discovery extended.** `_discoverLGZ()`, `_discoverTRZ()` and their
  equivalents for AIZ_/WPZ_ are updated to read `zd.linkUnit` and call the unit-name resolver.

- **`dcsName` field already stored.** `CTLDTroopZone` already stores `self.dcsName` (the DCS
  trigger zone name). This is the key passed to `trigger.misc.getZone()`. No new field needed for
  the zone name.

## Testing Decisions

Good tests for this feature verify observable zone behavior (position returned, zone liveness) via
the public `getCenter()` / `isAlive()` / `isDynamic()` / `isInZone()` interfaces. They do not
assert on internal fields (`_anchorUnitName`, `_dcsZoneName`, etc.).

**Seam 1 — `tests/ci/unit/zone_manager_spec.lua` (existing, L1 busted)**
Extend with anchored-zone cases: verify that `_parseLGZ` / `_parseTRZ` correctly detect the
Moving Zone flag (`linkUnit` present) and populate `_anchorUnitName` from the mocked
`coalition.getGroups()` stub. Prior art: existing parse tests in `zone_manager_spec.lua`.

**Seam 2 — `tests/ci/unit/zone_anchored_spec.lua` (new, L1 busted)**
Unit tests with fully mocked DCS APIs (`trigger.misc.getZone`, `Unit.getByName`,
`coalition.getGroups`):
- `getCenter()` returns live position when `trigger.misc.getZone` returns a moving point
- `getCenter()` falls back to `_center` when `trigger.misc.getZone` returns nil
- `isDynamic()` returns true for anchored zones, false for static zones
- `isAlive()` returns false when `Unit.getByName` returns nil (anchor destroyed)
- `isInZone()` reconstructs polygon vertices from relative offsets + live center and correctly
  classifies points inside and outside the polygon

**Seam 3 — `tests/dcs/noPlayer/` L3 scenario (new, tier `auto-check`)**
Injected into `missions/Test_CTLDNEXT_01.miz` which already contains:
- `CTLD_TEST_ANCHOR_1` — vehicle with a route
- `LGZ_polygonAnchored_B` — polygon Moving Zone (type=2, 4 vertices, linkUnit=50)
- `TRZ_CircularAnchored_B_999_nil_0` — circular Moving Zone (type=0, linkUnit=50)

The scenario:
1. Reads `getCenter()` for both zones at t=0
2. Waits for the anchor vehicle to move (timer / `waitFor`)
3. Reads `getCenter()` again and asserts positions have changed
4. Destroys the anchor unit and asserts `isAlive()` returns false for both zones

## Out of Scope

- **Vehicle-as-pseudo-TRZ** — loading infantry groups into a moving vehicle so the vehicle acts as
  a mobile troop zone. Tracked in `dev/roadmap.md`.
- **STARTUP-REPORT-UNIFIED** — aggregated MM startup report. Separate lot, high priority after
  `FEAT-USERCONFIG-API`.
- **Dynamic zone creation from Lua** — DCS Moving Zones must be defined in the ME; they cannot be
  created at runtime from Lua.
- **Polygon zone rotation** — the `heading` field in `env.mission.triggers.zones` applies to the
  polygon's orientation relative to the unit. Vertex coordinates in the mission file are already
  stored in the rotated frame, so no rotation computation is needed.

## Further Notes

Live DCS tests during the grill confirmed:
- `trigger.misc.getZone()` returns live position for Moving Zones (positions changed by ~200 m
  between two injections while the anchor moved).
- When the anchor is destroyed, `trigger.misc.getZone()` returns the raw relative-offset
  coordinates from the ME (near world-origin, not nil and not the last live position). The
  `_anchorUnitName` / `isAlive()` guard is therefore the reliable destruction detector.
- `env.mission.triggers.zones` exposes `linkUnit` (integer unit ID) and `type` (0=circular,
  2=polygon). Polygon vertices are relative offsets when the zone is a Moving Zone.
- `getDesc()` on the anchor unit exposes no information about the Moving Zone link — the link is
  ME-only metadata.
