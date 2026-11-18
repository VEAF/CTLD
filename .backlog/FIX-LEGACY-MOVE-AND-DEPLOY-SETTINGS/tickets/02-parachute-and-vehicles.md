# 02 — Parachuted troops and whole vehicles unloaded act on their own

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS](../PRD.md), [ADR 0029](../../../dev/adr/0029-dropped-groups-act-alone-and-the-unpack-guard-is-optional.md). Stories 3, 4, 23, 24. GitHub issue #309.

## What to build

Two more ways a group reaches the ground now follow the behaviour built in ticket 01.

- **Parachuted troops**: once they land and their group exists, they get the order of a dropped group (a waypoint zone and a template task keep priority).
- **A whole vehicle unloaded from a transport** gets the same order, a JTAC vehicle included (v1 parity, no exception). A vehicle that comes out of a crate being unpacked is not concerned: v1 did not move it either.

## Acceptance criteria

- [ ] Troops that land by parachute get the order of a dropped group: toward the nearest enemy in range, else a random point within `maximumMoveDistance`; a waypoint zone and a template task keep priority.
- [ ] A whole vehicle unloaded from a transport gets the same order, a JTAC vehicle included.
- [ ] A vehicle spawned by unpacking a crate gets no order.
- [ ] With both distances at 0 none of these gets an order.
- [ ] The new cases fail before the change and pass after it; the existing parachute and vehicle specs pass unchanged.
- [ ] `busted tests/ci/` green; luacheck clean.

## Blocked by

- [01 — Troops dropped by a pilot or an AI transport act on their own](01-dropped-groups-act-alone.md) (the behaviour and the settings)
