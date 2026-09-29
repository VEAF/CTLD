# 05 — Re-arm lock after a native release

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Story 9.

## What to build

A vehicle just released from native carry cannot be natively loaded again until it has been observed
**outside** its former transport's box enlarged by 0.5 m at least once, or until that transport no
longer exists. The margin is a local constant, not a configuration key.

This makes a load/unload loop impossible by construction: DCS may place a released vehicle still
under the aircraft's envelope, and until it clears the enlarged box it stays `WAITING` without being
loaded again.

The lock is per vehicle, is set at release, and is cleared by the condition above. It does not
affect vehicles that were never natively carried.

## Acceptance criteria

- [ ] A released vehicle placed inside the box stays `WAITING` and is not reloaded on the following
      ticks.
- [ ] Once seen outside the box plus 0.5 m, the vehicle can be natively loaded again.
- [ ] If the former transport disappears, the lock is released.
- [ ] A vehicle never natively carried is unaffected by the lock.
- [ ] Busted spec drives the sequence release, inside box, outside box, re-entry.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry (may share the ticket 04 entry).

## Blocked by

- [04 — Native vehicle release by drift](04-native-vehicle-release-by-drift.md)
