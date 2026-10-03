# 02 — Every timer call goes through the scheduler, enforced by a guard test

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-SCHEDULER-SINGLE-ENTRY](../PRD.md). Source: GitHub issue #234. Stories 1-3, 6-8, 11-12.

## What to build

A busted guard spec reads the merge list, scans each `src/` file ignoring comment lines, and fails when
`timer.scheduleFunction(` appears anywhere except the single call inside the scheduler (no exception list).
Write it first and watch it fail, then replace every direct call in `src/` by `ctld.scheduler.schedule` — a
mechanical replacement with no other edit at the site, including one-shot callbacks, the scene manager and
the menu debounce timers. `timer.removeFunction` calls are untouched.

## Acceptance criteria

- [ ] The guard spec fails before the migration and passes after it.
- [ ] No behaviour change: every existing spec passes unchanged.
- [ ] The merged `CTLD.lua` builds and loads (CI `Built CTLD.lua Loads`).
- [ ] luacheck clean; `busted` green.

## Blocked by

- [01 — scheduler.schedule and cancelAll](01-scheduler-schedule-and-cancelall.md)
