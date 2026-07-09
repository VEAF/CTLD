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

| Template | Shape |
|---|---|
| `tests/dcs/_template_noPlayer.lua` | Synchronous, single pcall, no player/timers — `noPlayer/` |
| `tests/dcs/_template_pilotPassive.lua` | Async (timers/`waitFor`), player drives, no F10 — `pilotPassive/` |
| `tests/dcs/_template_pilotActive.lua` | Async + F10 human menu steps — `pilotActive/` |
| `tests/dcs/_template_scenario.lua` | Generic version covering all four step types (auto/delayed/polled/human) |

Every template already emits the return contract above — replace `SCN-XXX` / `[SCN-XXX]` with a
real tag and fill in the steps.

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
