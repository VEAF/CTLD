---
name: integration-testing
description: Inject CTLD and DCS integration-test scenarios into a live mission via VEAF-dcs-bridge and read back the verdict. Use when running or writing a tests/dcs/ scenario, or debugging why one FAILs.
---

# DCS integration testing (dcs-bridge)

Scenarios in `tests/dcs/{noPlayer,pilotActive,pilotPassive}/` run against a live DCS mission
through **VEAF-dcs-bridge**, not Witchcraft. The bridge exposes DCS over MCP tools —
`exec_lua`, `get_units`, `spawn_unit`, `get_mission_info` — wired in the project's `.mcp.json`.

## Prerequisites

1. `dcs-serve` running on the machine hosting the live DCS mission (holds the TCP connection
   from the injected `dcs-bridge.lua`). Config: `dcs-serve.yaml`.
2. `dcs-client.yaml` (gitignored, machine-local) with an `api_key` matching `dcs-serve.yaml`.
3. The mission has the Lua bridge injected (see VEAF-dcs-bridge docs — VMCT v6 injection is the
   recommended method).
4. If `dcs-client` is not on `PATH`, install it (see ticket `07-dev-setup` / project README once
   landed) or run it from the `VEAF-dcs-bridge` checkout's venv.

Once these are up, `exec_lua` is available as an MCP tool.

## The injection loop

```
Modify src/  →  Rebuild (if src/ changed)  →  exec_lua CTLD.lua  →  wait ~3-5s for init
             →  exec_lua the scenario  →  read the verdict  →  iterate on FAIL
```

1. **Rebuild** if `src/` changed:
   `powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`
2. **Inject CTLD.lua**: `exec_lua(code=<contents of CTLD.lua>)`, then wait 3-5s (CTLD init is
   async — `CTLDCoreManager` and friends aren't available immediately).
3. **Inject the scenario**: `exec_lua(code=<contents of the scenario file>)`.
4. **Read the verdict** — see the return contract below.
5. **Iterate**: on FAIL, fix and re-inject without waiting for the user (autonomous debug loop —
   the user does not need to be in the loop between injections).

You (the AI) drive this loop end to end. Only pause for the user when a scenario requires a
human F10 action it cannot itself take (see pilotActive scenarios).

## Return contract

Every scenario's `exec` call returns (and mirrors into a global `_SCN_<ID>_RESULT`) one of:

| Verdict | Meaning |
|---|---|
| `<TAG> PASS` or `<TAG> PASS <p>/<t>` | All checks passed |
| `<TAG> FAIL: <reasons>` or `<TAG> FAIL <f>/<t>: <reasons>` | At least one check failed |
| `<TAG> ABORT: <msg>` | Preconditions unmet (e.g. CTLD not initialized, no BLUE player) |
| `<TAG> RUNNING` or `<TAG> RUNNING: <detail>` | Multi-step re-injection scenario, not finished — inject again |
| `<TAG> STARTED` | Async scenario just kicked off (timers / F10) — poll the result var next |

The decisive token is the word right after the tag. Count and reasons are optional detail —
fail-fast scenarios that don't track a pass/fail counter omit the count.

**Async scenarios** (timers, `waitFor`, F10 human steps): the initial `exec_lua` call returns
`STARTED` immediately; the actual verdict lands later in `_G["_SCN_<ID>_RESULT"]`. Poll it with a
follow-up call:

```lua
return _SCN_<ID>_RESULT
```

**Multi-step re-injection scenarios** (`step=N`, e.g. `farp_repack`, `mt07`-style scenarios):
each injection advances one step and returns `RUNNING: step=N ...` until the final step returns
`PASS`/`FAIL`. Re-inject the same file to advance.

## Writing a new scenario

Copy the template matching the scenario's shape:

| Template | Shape | Default `@tier` |
|---|---|---|
| `tests/dcs/_template_noPlayer.lua` | Synchronous, single pcall, no player/timers — `noPlayer/` | `auto` |
| `tests/dcs/_template_pilotPassive.lua` | Async (timers/`waitFor`), player drives, no F10 — `pilotPassive/` | `ia` |
| `tests/dcs/_template_pilotActive.lua` | Async + F10 human menu steps — `pilotActive/` | `ia` |
| `tests/dcs/_template_scenario.lua` | Generic version covering all four step types (auto/delayed/polled/human) | `auto` — retag per the concrete scenario's shape |

Every template already emits the return contract above — replace `SCN-XXX` / `[SCN-XXX]` with a
real tag and fill in the steps.

## `@tier` header

Every scenario carries a `-- @tier: auto | auto-check | ia` header line (placed right after
`---@diagnostic disable`). The tier is what `INTEGRATION-TEST-RUNNER`'s "run without AI" mode
filters on — it must reflect what the scenario actually needs, not just its folder:

| Tier | Operative test |
|---|---|
| `auto` | A single `exec_lua` call returns the definitive verdict (`PASS`/`FAIL`/`ABORT`). No player, no polling, no human/AI judgment. Includes scenarios using a *mocked* timer that fires synchronously. |
| `auto-check` | Resolves automatically (no human/AI judgment) but not in one call — returns `STARTED`, a real timer/`waitFor` resolves `_SCN_<ID>_RESULT` later. The runner must poll or re-inject. Rare: only scenarios with genuine unmocked async resolution qualify. |
| `ia` | Needs an AI agent or human in the loop — either a live player-controlled unit (dcs-bridge has no flight-control API; something has to fly the aircraft into position: all of `pilotActive/`/`pilotPassive/`) or a scenario that returns `STARTED` and never resolves programmatically, instead asking for an F10/visual confirmation the code itself never checks. |

Default for new scenarios: `noPlayer/` → `auto` unless it genuinely needs polling (`auto-check`)
or never resolves without a human look (`ia`, with a one-line rationale comment since the tier
isn't inferable from the folder); `pilotActive/`/`pilotPassive/` → always `ia`.

## Automated runs (no AI agent)

For `auto`/`auto-check` scenarios, you don't need to drive the injection loop by hand (or via
Claude) — `tools/integration-runner/run_scenarios.py` runs them headlessly against a live
`dcs-serve` and writes a JUnit report. Dependency-free (stdlib only), reads the same
`dcs-client.yaml`. See `tools/integration-runner/README.md` for the full flag reference; typical
use: `python tools/integration-runner/run_scenarios.py --no-ai --inject-ctld`. `ia`-tier
scenarios (player/F10 required) are never selected by `--no-ai` — those still need this skill's
AI-driven `exec_lua` loop.

## Debug config

See the `dcs-runtime-debug` skill for `debug`/`debugScreenLog` config and reading
`tests/dcs/CTLD.log` / `DCS.log`. This skill covers running/writing scenarios; that one covers
diagnosing a runtime failure from the logs.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `exec_lua` returns an httpx/503 error | `dcs-serve` down or DCS not connected | Start `dcs-serve`, confirm the mission has the bridge injected |
| `attempt to call field 'getInstance' (a nil value)` | CTLD not yet initialized | Wait longer after injecting `CTLD.lua`, or poll `tests/dcs/util/*ready*` style check |
| Verdict never leaves `STARTED` | Async scenario still running, or a timer errored silently | Poll `_SCN_<ID>_RESULT` again; check `CTLD.log` for a stuck step |
| `<TAG> RUNNING: step=N ...` forever | Re-injection scenario waiting on a DCS-side condition (player position, F10 click) | Perform the required in-game action, then re-inject |
