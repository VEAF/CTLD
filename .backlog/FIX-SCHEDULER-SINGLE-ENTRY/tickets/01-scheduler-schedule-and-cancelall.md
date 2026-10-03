# 01 — `ctld.scheduler.schedule` and a `cancelAll()` that cancels everything pending

**Status:** ✅ done (PR #244) · **Type:** AFK

## Parent

[PRD — FIX-SCHEDULER-SINGLE-ENTRY](../PRD.md). Source: GitHub issue #234. Stories 1, 5, 8-11.

## What to build

Add `ctld.scheduler.schedule(fn, arg, t)` (one-for-one replacement of `timer.scheduleFunction`, looked up at
call time) that records the pending id, keeps it tracked while the chain reschedules itself and forgets it
when the chain ends. `cancelAll()` cancels the union of the pending set and the named registry, each id once,
and logs the real count. `cancel(name)` and `register` also drop the id from the pending set.

Tests first, in a new scheduler spec driven by the stubbed `timer`: argument and return-value forwarding,
self-rescheduling (same id) vs ending (forgotten) vs manual re-scheduling (latest id), `cancelAll()` count
and effect, `register` replacement. Watch them fail, then implement.

## Acceptance criteria

- [ ] New busted cases fail before the change and pass after it (test committed first).
- [ ] The callback handed to DCS forwards its arguments and returns exactly the original's value.
- [ ] `cancelAll()` cancels each pending id once, named or not, and reports the real count.
- [ ] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
