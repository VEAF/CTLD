# FIX-SCHEDULER-SINGLE-ENTRY — one entry point for every timer, so `cancelAll()` cancels everything

**Status:** ✅ done (PR #NN)

Formalizes GitHub issue #234 (automated code review of `develop`), re-read against the current code: the
defect is still present. Last lot of the review follow-up, after `FIX-REVIEW-HYGIENE-A`,
`FIX-PARACHUTE-TROOPS-SPAWN-FAILURE` and `FIX-DCS-OBJECT-NAME-COMPARISON`. Decisions come from a
`grill-with-docs` session held 2026-10-03, with a live baseline run against a DCS mission.

## Problem Statement

`ctld.scheduler` is documented as the central registry of long-running loops, so that the development
workflow can inject a shutdown (`ctld.scheduler.cancelAll()`) before re-injecting CTLD. In practice 2 loops
out of roughly 15 register (`ai_transport`, `beacon_refresh`). Every other perpetual loop calls
`timer.scheduleFunction` directly and is invisible to the registry: hover slingload polling, the LGZ ground
poll, the smoke tick, the static watcher, the vehicle polls, the player in-air debounce and player scan, zone
smoke refresh, recon refresh, JTAC lasing, and the flag count watchers. The file the documentation says to
inject, `tests/dcs/util/shutdown_ctld.lua`, does not exist either.

After a re-injection the old timer chains survive and, since most wake up through `getInstance()`, they plug
into the **new** singletons. The hover poll then runs at 2 Hz instead of 1 Hz and decrements the hover counter
twice per second: pickup triggers after half of `hoverTime`, then a quarter after a second re-injection. Smoke,
recon and JTAC lasing double their rate at each cycle. The symptom is silent and points elsewhere, and
`cancelAll()` logs "2 loop(s) cancelled", which reads like a success.

A live baseline run (2026-10-03) found a second defect of the same contract: `CTLDBeaconManager:_scheduleRefresh`
guards against a double start with a private flag that `cancelAll()` never clears, so after `cancelAll()` the
beacon loop cannot be restarted in the same instance (scenario check F-139.4 fails on `develop`).

The cause is structural, not the 13 forgotten call sites: any loop added tomorrow can forget to register as
well.

## Solution

A single entry point, `ctld.scheduler.schedule(fn, arg, t)`, replaces every direct `timer.scheduleFunction`
call in `src/`. It records the id of every pending timer, keeps it up to date as chains reschedule or end, and
`cancelAll()` cancels everything still pending. A busted test fails if `timer.scheduleFunction` appears in
`src/` anywhere else, so a loop can no longer opt out. The beacon loop's idempotence is read from the registry
instead of a separate flag. A shutdown script and a live scenario complete the workflow.

## User Stories

1. As a CTLD developer re-injecting CTLD into a running mission, I want `cancelAll()` to stop every loop of
   the previous instance, so that the new instance does not run on top of zombie timers.
2. As a CTLD developer, I want the hover poll to run at its normal rate after a re-injection, so that hover
   pickup timing is not silently halved.
3. As a CTLD developer, I want smoke, recon and JTAC lasing not to double their rate after a re-injection, so
   that a debug session does not drift.
4. As a CTLD developer, I want a shutdown script I can inject before re-injecting, so that the documented
   procedure works.
5. As a CTLD developer, I want `cancelAll()` to report how many timers it really cancelled, so that the log
   line means something.
6. As a CTLD developer adding a new loop, I want `ctld.scheduler.schedule` to be the only way to schedule, so
   that I cannot forget to register it.
7. As a CTLD developer, I want a CI test to fail when `timer.scheduleFunction` is called directly in `src/`,
   so that the rule is enforced rather than remembered.
8. As a CTLD developer, I want one-shot delayed callbacks tracked too, so that nothing scheduled by CTLD can
   fire into a re-injected instance.
9. As a CTLD developer, I want a self-rescheduling callback (returns the next time) to stay tracked under the
   same id, and a callback that returns nothing to be forgotten, so that the registry never grows.
10. As a CTLD developer, I want a chain that reschedules by calling the scheduler again (hover poll) to
    always have its latest id tracked, so that cancelling it works.
11. As a CTLD developer, I want the DCS semantics of the callback preserved exactly (arguments, return value),
    so that no loop changes behaviour.
12. As a mission maker, I want no behaviour change in a normal mission, so that this tooling fix cannot affect
    play.
13. As a CTLD developer, I want the beacon refresh loop to restart after `cancelAll()`, so that the shutdown /
    re-init cycle works for beacons too.
14. As a CTLD developer, I want the beacon double-start guard to keep preventing two loops, so that
    transmissions are not refreshed twice.
15. As a CTLD developer, I want a live scenario that schedules a counting loop of each kind, cancels, and
    checks the counters freeze in real DCS, so that the claim does not rest on stubs.
16. As a CTLD developer, I want that scenario to check the real CTLD loops are gone after `cancelAll()`, so
    that the end-to-end promise of the issue is verified.
17. As a maintainer, I want a CHANGELOG entry, so that release notes mention the fix.
18. As a maintainer, I want the developer documentation to describe the single entry point, so that
    contributors know the rule.

## Implementation Decisions

- **Entry point:** `ctld.scheduler.schedule(fn, arg, t)` returns the DCS function id, a one-for-one
  replacement of `timer.scheduleFunction`. It looks `timer.scheduleFunction` up at call time (stubs in tests
  keep working). The callback it hands to DCS forwards its arguments and returns exactly what the original
  returns: a number means DCS reschedules the **same id** (the id stays tracked), anything else ends the
  chain (the id is forgotten). A callback that fails is left to DCS, as before.
- **Registry:** a set of pending ids next to the existing named registry. `cancelAll()` cancels the union of
  both (each id once), clears both, and logs the number actually cancelled. `cancel(name)` and `register`
  also drop the id from the pending set.
- **Named loops stay named:** `ai_transport` and `beacon_refresh` keep `register(name, fid)` as a
  double-start guard; their id now comes from `schedule`.
- **Migration:** every `timer.scheduleFunction` call in `src/` (including one-shot delayed callbacks, the
  scene manager and the menu debounce timers) becomes `ctld.scheduler.schedule`, a mechanical replacement
  with no other edit at the site. Timer removals by id keep using `timer.removeFunction`.
- **Guard test:** a busted spec reads the merge list, scans each `src/` file ignoring comment lines, and fails
  when `timer.scheduleFunction(` appears anywhere except the one call inside the scheduler. No exception
  list.
- **Beacon idempotence:** `_scheduleRefresh` returns early when `beacon_refresh` is already registered,
  instead of consulting a private flag; the flag is removed. The unit spec that pre-sets the flag to avoid a
  real loop is adapted.
- **Tooling:** `tests/dcs/util/shutdown_ctld.lua` is created (it only calls `cancelAll()`), so the comment
  and the existing scenario that reference it become true. The existing scheduler scenario is extended with
  the live checks described under Testing.
- **No behaviour change in a normal mission, no config, i18n, schema or catalogue change.**
- **Legacy parity:** the legacy script has no scheduler registry; nothing to preserve.

## Testing Decisions

- A good test observes external behaviour: which pending timers `cancelAll()` cancels, what a wrapped
  callback receives and returns, whether a loop restarts. It does not inspect how ids are stored.
- Seam: a new busted spec for the scheduler, driven through the stubbed `timer` (the stub records
  scheduled callbacks and removed ids). Cases written first and seen failing: `schedule` forwards arguments
  and the return value; a self-rescheduling callback keeps its id pending, a callback returning nil is
  forgotten; a manually re-scheduled chain has its latest id pending; `cancelAll()` removes every pending id
  once, including named ones, and reports the real count; `register` still replaces a previous id of the
  same name.
- The guard spec described above, failing first (the migration is its own ticket, the guard is added with it
  and fails until the migration is done).
- The beacon spec: `_scheduleRefresh` called twice schedules once; called after `cancelAll()` schedules
  again (failing first).
- Existing specs that stub `timer.scheduleFunction` pass unchanged.
- **Live DCS (done by the developer with a running mission, through `run_scenarios.py`, never the MCP):** the
  extended scheduler scenario, after a mission reload on the built `CTLD.lua`: a counting loop that returns
  `t + 1` and one that reschedules itself by calling `schedule` both advance, then freeze after
  `cancelAll()`; the real CTLD loops (hover, smoke, vehicle polls…) no longer run; F-139.4 passes. Baseline
  before the change (2026-10-03): 21 of 22 checks pass, F-139.4 fails.

## Out of Scope

- Cancelling DCS event handlers or any non-timer state on shutdown.
- Re-initialising CTLD in place (the supported way remains reloading the mission; injecting `CTLD.lua` over a
  live mission is still forbidden).
- Changing any loop's period or behaviour.

## Further Notes

Source issue: #234 (found at `8d37a58`). The PR references it with `Fixes #234`.
