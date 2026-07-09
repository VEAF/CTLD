# Lot DCS-BRIDGE-MCP — migrate DCS integration testing from Witchcraft to VEAF-dcs-bridge

Status: ✅ done (all 7 tickets complete — pending commit/PR)
Branch: feature/dcs-bridge-mcp → PR (pending) → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

## Problem Statement

DCS integration testing currently runs entirely on **Witchcraft** (jboecker/dcs-witchcraft):
a Node.js `bridge.js` injects Lua into a live mission, and the ~273 scenarios in `tests/dcs/`
are written around it. This has concrete limits:

- **Witchcraft is a dead-end for automation.** It is a manual, browser/CLI debug tool — there is
  no REST API to script a headless run. A CI-style "run all auto scenarios" is impossible.
- **The return contract is a hack.** Scenarios end with `return Witchcraft` (the Witchcraft
  global object), and the real verdict is only written to `CTLD.log` / the DCS screen. There is
  no machine-parsable verdict a runner could consume. The format is also inconsistent across
  scenarios (some `return "[TAG] FAIL: ..."`, most `return Witchcraft`).
- **VEAF now ships a purpose-built replacement.** `VEAF-dcs-bridge` (v0.6.1) exposes DCS over a
  clean REST/MCP surface: `dcs-serve` (`POST /api/exec` runs arbitrary Lua and returns its string
  result) and `dcs-client mcp` (FastMCP over stdio: `exec_lua`, `get_units`, `spawn_unit`,
  `get_mission_info`). This is the intended long-term transport for both AI-driven and headless
  integration testing.
- **CLAUDE.md already describes the target as if it existed** (`dcs-client mcp`, `-- @tier:`
  headers, a single `_template_scenario.lua`) — it is aspirational. The repo actually has four
  templates and zero tagged scenarios. Doc and reality must be reconciled.

This lot is the **switchover**: after it, Witchcraft is gone and every scenario runs on the
bridge with a clean, parsable verdict contract. Tier tagging (INTEGRATION-TEST-TAGS) and the
Python runner (INTEGRATION-TEST-RUNNER) build on top of it.

## Solution

1. Wire the bridge into the repo: a project `.mcp.json` launching `dcs-client mcp`, plus config
   guidance (`dcs-client.yaml` / `dcs-serve` prerequisites, API key).
2. Define a **standard scenario return contract** parsable by an external runner, covering both
   synchronous scenarios (verdict in the `exec` return) and asynchronous ones (timers / F10 human
   steps — verdict polled from a global result variable).
3. Migrate the four scenario templates to the new contract and reconcile CLAUDE.md.
4. **Big-bang migrate the ~273 scenarios** to the new contract (drop `return Witchcraft` and the
   Witchcraft guards, emit the standard verdict), preserving each scenario's in-game behaviour.
5. Replace the Witchcraft debug workflow with an `integration-testing` skill.
6. Remove Witchcraft from the tooling: `.claude/witchcraft-workflow.md`, the `.vscode` task, and
   all references in `CLAUDE.md` / `CONTEXT.md` / `docs/`.

Tier tagging is **out of scope** here (INTEGRATION-TEST-TAGS) even though both passes touch the
273 files — keeping the migration diff and the tagging diff separate keeps each PR reviewable.

## User Stories

1. As a maintainer, I want a project `.mcp.json` that launches `dcs-client mcp`, so that Claude
   can drive a live DCS mission over the bridge without any Witchcraft setup.
2. As a maintainer, I want a single documented **return contract** for scenarios, so that a runner
   (and Claude) can read a PASS/FAIL verdict programmatically instead of scraping logs.
3. As a scenario author, I want the templates to embody the new contract, so that new scenarios
   are bridge-native by construction.
4. As a maintainer, I want the ~273 existing scenarios migrated to the contract with identical
   in-game behaviour, so that nothing regresses when Witchcraft is removed.
5. As a maintainer, I want an `integration-testing` skill replacing the Witchcraft workflow doc,
   so that the injection/debug loop is documented for the bridge.
6. As a maintainer, I want every Witchcraft reference removed from the repo, so that the tooling
   is honest about what actually runs.

## Return contract (bridge era)

Scenarios run through `POST /api/exec`, whose JSON response carries the Lua snippet's string
`result`. The contract:

- **Verdict strings** (what the runner parses). The decisive token is the word right after the
  tag (`PASS` / `FAIL` / `ABORT` / `RUNNING` / `STARTED`); the count and reasons are optional
  diagnostic detail (fail-fast scenarios that don't keep a counter omit the count):
  - `<TAG> PASS` or `<TAG> PASS <passed>/<total>` — e.g. `[F-178] PASS`, `[SCN-42] PASS 5/5`
  - `<TAG> FAIL: <reasons>` or `<TAG> FAIL <failed>/<total>: <reasons>`
  - `<TAG> ABORT: <msg>` — preconditions unmet (e.g. CTLD not initialised)
  - `<TAG> RUNNING` — async scenario not finished yet
  where `<TAG>` is the scenario's existing bracketed tag (`[SCN-XXX]` / `[F-nnn]`).
- **Global result variable**: every scenario sets `_G[RESULT_KEY]` (`RESULT_KEY = "_SCN_<ID>_RESULT"`)
  to its current verdict string. It starts at `RUNNING`/`STARTED` and is overwritten with the
  final `PASS`/`FAIL`/`ABORT` verdict when the scenario ends.
- **Immediate `exec` return**:
  - *Synchronous* scenarios (fully inline, no timers) `return` the final verdict directly.
  - *Asynchronous* scenarios (timers / `waitFor` / F10 human steps) `return "<TAG> STARTED"`; the
    runner then polls `_G[RESULT_KEY]` via a follow-up `exec_lua("return _SCN_<ID>_RESULT")` until
    it reads `PASS`/`FAIL`/`ABORT` or hits a timeout.
- **No `return Witchcraft`.** The Witchcraft global disappears. For transition robustness a
  neutral shim (`Witchcraft = Witchcraft or {}`) MAY be injected by the runner, but migrated
  scenarios must not depend on it.

The exact wording is frozen by ticket 02 (spec + helper in the template); the runner-side parser
lives in INTEGRATION-TEST-RUNNER.

## Non-goals

- Tier `@tier:` headers and tagging — INTEGRATION-TEST-TAGS.
- The Python runner, JUnit report, CI wiring — INTEGRATION-TEST-RUNNER.
- Any change to CTLD `src/` behaviour. Scenario migration is contract-only; in-game behaviour is
  preserved (legacy parity).

## Addendum — dev-setup (ticket 07)

`.mcp.json` launches `dcs-client` from a project-local, gitignored venv
(`tools/dcs-bridge/venv/`) rather than relying on the system PATH, so any contributor gets a
working `dcs-bridge` MCP server from a fresh checkout via `tools/dcs-bridge/install.ps1`
(`${CLAUDE_PROJECT_DIR}`-relative paths, no vendored bridge source). This surfaced and led to
fixing an upstream packaging bug in `VEAF-dcs-bridge` (missing `[build-system]` table — PR #15,
`develop`, v0.6.2) that blocked *any* `pip`/`pipx` install of the bridge, not just this one.
