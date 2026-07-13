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
   from the injected `dcs-bridge.lua`). Config: `dcs-serve.yaml` (run `tools/dcs-bridge/venv/
   Scripts/dcs-serve.exe` — first launch generates the API key and the yaml file).
2. `dcs-client.yaml` (gitignored, machine-local, repo root) with an `api_key` matching
   `dcs-serve.yaml`.
3. The mission has `dcs-bridge.lua` injected (DO SCRIPT FILE trigger, or MissionScripting.lua —
   see VEAF-dcs-bridge's `docs/guide/prerequisites.md`).
4. **`dcsBridge` port config, set in a DO SCRIPT action right BEFORE the DO SCRIPT FILE that
   loads `dcs-bridge.lua`** — easy to miss, causes a silent connection failure (no error
   anywhere, `dcs-serve`'s console just never shows "DCS connected"):
   ```lua
   dcsBridge = { host = "127.0.0.1", port = 7777 }
   ```
   `dcs-bridge.lua` defaults to port **9001** if this isn't set. `dcs-serve`'s own default
   (`ServeConfig.tcp_port`) is **7777** — check the actual value in your `dcs-serve.yaml`
   (`tcp_port`) and match it here; don't assume a specific number.
5. `dcs-client`/`dcs-serve` are installed at `tools/dcs-bridge/venv/Scripts/` via
   `tools/dcs-bridge/install.ps1` (project-local venv, gitignored). `.mcp.json` already points
   there for the MCP server.

Once these are up, `exec_lua` is available as an MCP tool.

## The injection loop

```
Modify src/  →  Rebuild (if src/ changed)  →  reload mission (Shift+R, if src/ changed)
             →  exec_lua the scenario  →  read the verdict  →  iterate on FAIL
```

1. **Rebuild** if `src/` changed:
   `powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`
2. **Load the new CTLD code** — how depends on whether `src/` changed:
   - **Scenario-only change** (no `src/` change): nothing to reload — CTLD is already in memory,
     just inject the scenario (step 3).
   - **`src/` changed** (so `CTLD.lua` was rebuilt): **ask the user to reload the mission with
     `Shift+R`** in DCS. This restarts the mission from a clean state and re-`dofile`s the fresh
     `CTLD.lua` from disk (the MISSION START trigger does this).
     ⚠️ Do **NOT** inject the whole `CTLD.lua` via `exec_lua`/`--inject-ctld`: the file is ~1.2 MB
     and a single exec **times out (HTTP 504)**. And do **NOT** `dofile("…/CTLD.lua")` over a live
     mission — it re-runs CTLD init (scheduler, event handlers, timers) on top of the existing
     one and **freezes the DCS Lua thread**. Reloading the mission is the only safe way.
3. **Inject the scenario**: `exec_lua(code=<contents of the scenario file>)` (small file — fine).
4. **Read the verdict** — see the return contract below.
5. **Iterate**: on FAIL, fix and re-inject without waiting for the user (autonomous debug loop —
   the user does not need to be in the loop between injections). If the fix is in `src/`, a
   mission reload (`Shift+R`) is needed again before re-testing.

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
scenarios (player/F10 required) are never selected by `--no-ai`.

Most `ia`-tier `pilotActive`/`pilotPassive` scenarios self-verify (same `checkMenuExpected()`
pattern as `auto`) and only need a live pilot, not AI judgment — run those interactively from
the terminal with `tools/integration-runner/run_ia_scenario.py --scenario <name>` instead of
this skill's manual `exec_lua` loop (see that tool's README for details, including how to
restart a crashed test by just re-running the same command). Fall back to the manual
`exec_lua` loop below only for genuine visual/subjective-judgment scenarios (e.g. "menu looks
identical after a second refresh") or when debugging a scenario itself.

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
| `dcs-serve` console never shows "DCS connected" | `dcsBridge` port not set (or set wrong) in the mission trigger — `dcs-bridge.lua` defaults to port 9001, unrelated to `dcs-serve`'s own default (7777) | Add `dcsBridge = { host = "127.0.0.1", port = <dcs-serve's tcp_port> }` as a DO SCRIPT action right before the DO SCRIPT FILE that loads `dcs-bridge.lua` |
| DCS Mission Editor fails to load a `.miz` with `VFS_open_write: Can't create file ...l10n\DEFAULT\<name>` | A large embedded `l10n/DEFAULT/` resource (seen with a 420KB `.ogg`) breaks the editor's own unpacker — not a zip-structure issue (verified: intact archive, explicit zip directory entries made no difference) | Replace the offending resource with a small placeholder in the `.miz` (only if its content isn't needed for the tests you're running) |
