# 01 — Troops dropped by a pilot or an AI transport act on their own

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS](../PRD.md), [ADR 0029](../../../dev/adr/0029-dropped-groups-act-alone-and-the-unpack-guard-is-optional.md). Stories 1, 2, 3 (rope), 5, 6, 7, 8, 9, 10, 11, 23, 24, 25. GitHub issue #309.

## What to build

The foundation: the behaviour of a dropped group, and the settings that drive it, for the troops a player or an AI transport drops on the ground or by fast-rope.

- **The behaviour, decided in one place** that the other drop paths (tickets 02 and 03) will call. The nearest alive leader of an enemy ground group within `maximumSearchDistance` of the drop point, with no line-of-sight requirement, gets the group ordered toward it (two waypoints, off road); with none in range, the group is ordered toward a random point within `maximumMoveDistance` of the drop point. A waypoint zone keeps priority (the group marches to its centre), then a task the troop template declares; this default comes last. Both distances at 0 give no order. A drop into an extraction zone spawns no group, so nothing happens.
- **The settings.** `maximumMoveDistance` joins the catalogue (2000, metres); `maximumSearchDistance` goes back from 3000 to 4000. The catalogue version goes up and its shape is recorded, as the project requires for a new key. The `ctld-tools` schema gets the new setting (group troops, English and French label and description, unit, advanced) and the clarified description of `maximumSearchDistance`; both descriptions carry the tip that setting both distances to 0 leaves a dropped group where it was dropped.
- **The documentation** of the two settings in the mission makers' tables, English and French.

## Acceptance criteria

- [ ] A group dropped with an enemy ground group in range is ordered toward the nearest one (no line of sight needed).
- [ ] With none in range it is ordered toward a random point within `maximumMoveDistance` of the drop point; the random source is the only thing a test fixes.
- [ ] With both distances at 0 no order is given.
- [ ] A waypoint zone and a template task keep priority over this default; a drop into an extraction zone orders nothing.
- [ ] A pilot's ground drop, a fast-rope drop and an AI transport's drop all behave so.
- [ ] `maximumMoveDistance` (2000) is in the catalogue, `maximumSearchDistance` defaults to 4000; the catalogue version is raised and its shape file recorded; the `ctld-tools` schema and the settings tables (EN and FR) describe both settings.
- [ ] The new cases fail before the change and pass after it; the existing troop specs pass unchanged (the drop specs that assert no order are updated only where they now contradict the decision).
- [ ] `busted tests/ci/` green; luacheck clean; the catalogue shape test passes.

## Blocked by

None - can start immediately.
