# 04 — Big-bang migrate the ~273 scenarios

Status: ✅ done (79 sane scenarios migrated — see PRD note on the 194 dead relics excluded)
Type: AFK

## What to build

Migrate every scenario under `tests/dcs/{noPlayer,pilotActive,pilotPassive}/` (~273 files) to the
return contract (ticket 02). Per file:

- Remove Witchcraft guards (`return Witchcraft` on the abort/double-injection paths and at EOF).
- Replace the abort path with `<TAG> ABORT: <msg>` (still short-circuits when CTLD not ready).
- Emit the standard verdict string; set `_G["_SCN_<ID>_RESULT"]`.
- Synchronous scenarios `return` the verdict; asynchronous ones `return "<TAG> STARTED"` and
  write the final verdict to the result variable when they finish.
- **Preserve in-game behaviour exactly** — this is a contract-only migration, not a rewrite. No
  change to what the scenario spawns, checks, or asserts.

`tests/dcs/dev/` (155 diag files) and `tests/dcs/util/` (14 helpers) are **out of scope** unless
a helper is shared by migrated scenarios and breaks (fix minimally if so).

Automate with parallel agents (one batch of files per agent), each verifying `luac5.1 -p` on its
output. Spot-check a sample for behaviour parity against the pre-migration version.

## Acceptance criteria

- [ ] Zero `return Witchcraft` left under the three scenario dirs (`grep` clean).
- [ ] Every migrated scenario emits a contract-compliant verdict.
- [ ] `luac5.1 -p` clean across all migrated files.
- [ ] Behaviour parity: spot-checked sample shows identical spawns/checks/assertions.
- [ ] `dev/` and `util/` untouched (except forced minimal helper fixes, documented).

## Blocked by

Ticket 03 (templates set the pattern) — and a human checkpoint on the pattern before fan-out.
