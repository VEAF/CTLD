# 03 — Beacon refresh loop: idempotence read from the registry

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-SCHEDULER-SINGLE-ENTRY](../PRD.md). Found by the live baseline of 2026-10-03 (scenario check
F-139.4). Stories 13-14.

## What to build

`CTLDBeaconManager:_scheduleRefresh` returns early when `beacon_refresh` is already registered, instead of
consulting a private flag that `cancelAll()` never clears; the flag is removed. Test first: calling it twice
schedules once; calling it after `cancelAll()` schedules again. Adapt the existing unit spec that pre-sets the
flag to avoid a real loop.

## Acceptance criteria

- [ ] New cases fail before the change and pass after it.
- [ ] The double-start guard still prevents two loops.
- [ ] No reference to the removed flag remains.
- [ ] luacheck clean; `busted` green.

## Blocked by

- [01 — scheduler.schedule and cancelAll](01-scheduler-schedule-and-cancelall.md)
