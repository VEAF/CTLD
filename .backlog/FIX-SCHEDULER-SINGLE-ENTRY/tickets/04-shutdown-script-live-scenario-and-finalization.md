# 04 — Shutdown script, live scenario, docs and finalization

**Status:** ✅ done (PR #NN) · **Type:** HITL (live DCS validation by the developer)

## Parent

[PRD — FIX-SCHEDULER-SINGLE-ENTRY](../PRD.md). Source: GitHub issue #234. Stories 4, 15-18.

## What to build

- Create `tests/dcs/util/shutdown_ctld.lua` (calls `ctld.scheduler.cancelAll()`), referenced by the
  scheduler comment and by the existing scenario.
- Extend `tests/dcs/noPlayer/scenario_scheduler.lua`: schedule a counting loop that returns `t + 1` and one
  that reschedules itself through `schedule`, check both advance, call `cancelAll()`, check both freeze;
  check the real CTLD loops no longer run; F-139.4 passes.
- Developer documentation: describe the single entry point and the rule enforced by the guard spec.
- `CHANGELOG.md` `[Unreleased]` entry; rebuild `CTLD.lua`, confirm the i18n dictionaries are unchanged;
  index line `merged (PR #NN)`; PRD and tickets ✅; PR referencing `Fixes #234`.
- Run the scenario live (mission reloaded on the built `CTLD.lua`, `run_scenarios.py`, never the MCP) and
  record the result in the PR.

## Acceptance criteria

- [ ] `shutdown_ctld.lua` exists and the scenario references it.
- [ ] The extended scenario passes live (22 of 22 plus the new checks); result recorded in the PR.
- [ ] Docs, CHANGELOG, index and statuses done; dictionaries unchanged.
- [ ] CI green.

## Blocked by

- [02 — Every timer call goes through the scheduler](02-migrate-every-timer-call-and-guard.md)
- [03 — Beacon refresh idempotence](03-beacon-refresh-idempotence-from-registry.md)
