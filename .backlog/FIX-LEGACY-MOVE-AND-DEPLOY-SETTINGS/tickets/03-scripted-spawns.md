# 03 — Scripted spawns keep the v1 meaning of their search distance

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS](../PRD.md), [ADR 0029](../../../dev/adr/0029-dropped-groups-act-alone-and-the-unpack-guard-is-optional.md). Stories 12, 13, 23, 24. GitHub issue #309.

## What to build

A group a mission script spawns (`spawnGroupAtTrigger`, `spawnGroupAtPoint`) is a dropped group too, so it acts on its own, and the deprecated v1 functions keep the v1 meaning of their last argument.

- The two CTLD 2 methods gain a new optional **search-distance** parameter; `nil` means `maximumSearchDistance`. Their existing `radius` stays the placement circle.
- The deprecated `ctld.spawnGroupAtTrigger` and `ctld.spawnGroupAtPoint` pass their last argument through that parameter, as v1 read it: a negative value counts as 0, and with 0 no enemy is looked for, so the group walks at random within `maximumMoveDistance` (what the v1 code does, whatever its comment says).
- The spawned group gets the order of a dropped group (ticket 01).

## Acceptance criteria

- [ ] A scripted spawn with no search distance orders the group as a dropped group, with `maximumSearchDistance`.
- [ ] A scripted spawn with a search distance looks for the enemy within that distance; with 0 it looks for none and walks at random.
- [ ] The deprecated `ctld.*` wrappers pass their last argument as the search distance, a negative one as 0.
- [ ] The CTLD 2 methods keep `radius` as the placement circle; an existing call with `radius` only is unchanged in placement.
- [ ] The new cases fail before the change and pass after it; the existing scripted-spawn specs pass unchanged.
- [ ] `busted tests/ci/` green; luacheck clean.

## Blocked by

- [01 — Troops dropped by a pilot or an AI transport act on their own](01-dropped-groups-act-alone.md) (the behaviour and the settings)
