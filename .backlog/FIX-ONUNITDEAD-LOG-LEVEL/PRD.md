# FIX-ONUNITDEAD-LOG-LEVEL — stop `onUnitDead` flooding the log for deaths CTLD has no business with

**Status:** ⬜ ready

Closes [GitHub issue #212](https://github.com/VEAF/CTLD/issues/212) ("onUnitDead logs at INFO on the
normal case, flooding the log (1264 lines in one session)", davidp57/Zip) on merge. The issue text
already resolves root cause, fix and evidence; read the decisions below as settled.

## Problem Statement

A Mission Maker or server operator reading `dcs.log` on a busy multiplayer mission sees
`onUnitDead: no group found for unit '…' — skipping` **1264 times in one session**. Almost every
death DCS reports through `S_EVENT_DEAD` (scenery, debris, unnamed objects, units owned by other
mission scripts) is not a CTLD troop, so CTLD's "no group found" outcome is the normal case, not
an anomaly. The line buries the log entries that matter and even got reported as a bug.

## Solution

`CTLDTroopManager:onUnitDead` logs the "no group found" outcome at `DEBUG`, the level its two
sibling early-exit branches (no initiator, `getName()` failed) already use. Behaviour is otherwise
unchanged: a death belonging to no CTLD group is still skipped. The genuine success-path lines
(`removed from group`, `JTAC unit deregistered`, orphaned-servant despawn) stay at `INFO`.

## User Stories

1. As a server operator, I want a normal, uninteresting death to leave no `INFO` line, so that
   `dcs.log` stays readable over a long session.
2. As a Mission Maker debugging a real problem, I want `INFO` lines to signal events CTLD acted on,
   so that I can trust them as a summary of what happened.
3. As a developer diagnosing a missed troop death, I want the "no group found" line still available
   at `DEBUG`, so that I can turn it on when investigating.
4. As a pilot whose troops die, I want group cleanup, JTAC deregistration and servant despawn to
   behave exactly as today, so that this fix regresses nothing.

## Implementation Decisions

- Only the log level of the "no group found" branch changes, `INFO` → `DEBUG`. Message text, control
  flow (early return) and the other branches are untouched.
- No change to which events reach the handler and no filtering of numeric/unnamed ids: the level is
  the only defect (per the issue).
- Legacy parity: `migration/source/` has no equivalent handler; in-game behaviour is unchanged
  (log verbosity only).

## Testing Decisions

- A good test asserts external behaviour: the log level emitted for an unknown unit, and that the
  handler still returns without error.
- Seam: the existing `F-037 — onUnitDead` suite in `tests/ci/functional/troop_manager_spec.lua`
  (highest existing seam, already builds the dead-unit mock). Capture `ctld.utils.log` calls the
  way `tests/ci/unit/static_watcher_spec.lua` does.
- Cases: unknown unit → no `INFO` emitted (a `DEBUG` line is); known troop → `INFO`
  `removed from group` still emitted.

## Out of Scope

- Filtering numeric/unnamed ids before the group lookup.
- Auditing other handlers' log levels.
- Any change to `onUnitDead` behaviour.

## Further Notes

Requires a `CHANGELOG.md` `[Unreleased]` entry (`changelog-guard`). Rebuild `CTLD.lua` after the
`src/` change per project workflow.
