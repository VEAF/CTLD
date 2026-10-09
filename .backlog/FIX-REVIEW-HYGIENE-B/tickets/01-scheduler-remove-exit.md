# 01 — `ctld.scheduler.remove`: the exit symmetric to `schedule`

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-REVIEW-HYGIENE-B](../PRD.md). Source: GitHub issue #254. Decision D4.

Files: `src/CTLD_utils.lua` (`ctld.scheduler`), `src/CTLD_menu.lua`, `src/CTLD_recon.lua`, `tests/ci/unit/scheduler_spec.lua`, `tests/ci/unit/scheduler_guard_spec.lua`, `docs/developer/architecture.md` (+ `.fr.md`, scheduler section).

## What to build

- `ctld.scheduler.remove(id)`: `pcall(timer.removeFunction, id)` then `_pending[id] = nil`; returns at once for a nil id.
- `register` (previous id of the same name) and `cancel(name)` go through it.
- The six direct `timer.removeFunction` calls of `src/CTLD_menu.lua` (`:159`, `:220`, `:226`) and `src/CTLD_recon.lua` (`:607`, `:692`, `:781`) become `ctld.scheduler.remove`; the comment of `src/CTLD_menu.lua:168` that names `timer.removeFunction` follows.
- The guard spec gains a second case: no `src/` file other than `CTLD_utils.lua` mentions `timer.removeFunction` outside a comment, and `CTLD_utils.lua` mentions it exactly twice (`remove`, `cancelAll`).

## Acceptance criteria

- [x] busted, written first and seen failing: `remove` cancels the id in DCS and drops it from `_pending`; after `remove(a)`, `cancelAll()` cancels only what is still pending; `remove(nil)` and an id DCS refuses raise nothing.
- [x] The new guard case fails on `develop` (six offenders) and passes after the migration.
- [x] Existing menu and recon specs pass unchanged.
- [x] Developer doc of the scheduler names `remove` (EN + FR).
- [x] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
