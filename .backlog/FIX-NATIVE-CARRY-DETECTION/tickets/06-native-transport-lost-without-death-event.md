# 06 — Native-carry vehicle whose transport vanishes without a death event

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 10, 12, 19.

## What to build

CTLD already handles a transport destroyed by a death event: its loaded vehicles are dropped from
tracking, a JTAC is deregistered silently and `OnVehicleDead` is published. A transport can also
vanish without any death event (slot change, despawn). The native tick now detects that the
recorded transport of a native-carry vehicle no longer exists and applies **the same handling**.

The handling is idempotent: if a death event arrives as well, the vehicle is not processed twice.
Virtual-carry vehicles keep their current behavior.

## Acceptance criteria

- [ ] A native-carry vehicle whose transport no longer exists is removed from tracking, its JTAC (if
      any) is deregistered silently, and `OnVehicleDead` is published once.
- [ ] The same vehicle handled after a death event is not handled a second time.
- [ ] The vehicle's laser code and claim are freed when it was a JTAC.
- [ ] Busted spec covers disappearance with and without a death event.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry.

## Blocked by

- [04 — Native vehicle release by drift](04-native-vehicle-release-by-drift.md)
