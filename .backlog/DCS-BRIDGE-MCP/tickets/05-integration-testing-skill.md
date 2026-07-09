# 05 — `integration-testing` skill (replaces the Witchcraft workflow)

Status: ✅ done
Type: AFK

## What to build

A project skill `integration-testing` that documents the bridge-based injection/debug loop,
replacing `.claude/witchcraft-workflow.md`. It should cover:

- Prerequisites: `dcs-serve` running, live mission with the `dcs-bridge.lua` injected, matching
  API key; the `.mcp.json` server (ticket 01).
- The loop: build `CTLD.lua` (if `src/` changed) → `exec_lua` CTLD.lua → wait for init →
  `exec_lua` the scenario → read the verdict (return contract, ticket 02) → iterate on FAIL.
- Async scenarios: return `STARTED`, then poll `_G["_SCN_<ID>_RESULT"]`.
- Debug modes (`debug` / `debugScreenLog`) and reading `CTLD.log` — port the still-relevant parts
  of the Witchcraft doc, drop the `bridge.js`/Node specifics.
- Relationship to the existing `dcs-runtime-debug` skill (log reading) — no overlap/duplication.

## Acceptance criteria

- [ ] Skill exists and describes the full bridge loop end to end.
- [ ] References the return contract and the `.mcp.json` tools.
- [ ] No Witchcraft/`bridge.js` references.
- [ ] Clear boundary with `dcs-runtime-debug`.

## Blocked by

Tickets 01 + 02 (needs the wiring and the contract to document).
