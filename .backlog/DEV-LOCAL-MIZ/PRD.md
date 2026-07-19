# Lot DEV-LOCAL-MIZ — load each developer's local CTLD.lua via an env var instead of a hardcoded miz path

Status: ⬜ ready
Branch: chore/dev-local-miz → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: none (dev tooling, not a deliverable-architecture decision)

## Problem Statement

The shared test mission `missions/Test_CTLDNEXT_01.miz` ("martyr") loads `CTLD.lua` from a
**hardcoded absolute path** baked into the MISSION START trigger. Extracted from the miz:

```lua
-- (1)
-- dofile("D:/dev/_VEAF/CTLD_Next/CTLD.lua")   -- David's line, commented out
dofile("C:/CTLD.lua")                           -- active line
-- (2)
CTLDConfig.get().settings["ctldLogPath"] = "C:/CTLD.lua"
-- (3)
dcsBridge = { host = "127.0.0.1", port = 7777 }
-- (4)
a_do_script_file(<embedded dcs-bridge.lua>)
```

Each developer (David, FullGas, others) keeps `CTLD.lua` at a different location, so each one
comments/uncomments their own line (1). The `.miz` is **committed** (not gitignored), so every path
change rewrites a binary blob into git history — noise, plus the risk of leaving a personal-machine
path in a shared branch.

Two hardcoded machine paths were found, not one:

- **(1)** the `dofile` path — the actual subject.
- **(2)** `ctldLogPath = "C:/CTLD.lua"` — a **dead, broken** copy-paste. `ctldLogPath` is a *folder
  prefix* (`filePath = path .. "CTLD.log"`, [CTLD_utils.lua:1871](../../src/CTLD_utils.lua)), so this
  yields the absurd `C:/CTLD.luaCTLD.log`. It is also inert: `initLog()` returns early unless
  `debug == true` ([CTLD_utils.lua:1861](../../src/CTLD_utils.lua)), and the martyr never sets
  `debug = true`.

Line (3) is generic (loopback bridge endpoint) and line (4) embeds `dcs-bridge.lua` **inside** the
miz (`l10n/DEFAULT/dcs-bridge.lua` via `DO SCRIPT FILE`) — neither carries a machine path, so both
stay untouched.

### Why the trigger, not the runner

The integration runner already resolves `CTLD.lua` from the repo root with no machine path
(`run_scenarios.py --inject-ctld`, [run_scenarios.py:390](../../tools/integration-runner/run_scenarios.py)).
But `--inject-ctld` is `store_true` (default off): it is a **hot-reload** that overlays a fresh
`CTLD.lua`, not the base load. The **trigger** is the base load mechanism, common to both the
automated flow *and* the manual flow (opening the martyr in DCS to fly / test the pilot UX, where no
runner is present to inject). So the fix must target the trigger path itself.

## Solution

Replace the hardcoded `dofile` path (1) with a generic, machine-independent trigger that resolves
`CTLD.lua` from a per-developer environment variable, and delete the dead line (2). The `.miz`
becomes **stable and universal**: written once, committed once, then never touched again for a path
change.

Load resolution uses `CTLD_DEV_ROOT` (the repo root; the trigger appends `/CTLD.lua`), read via
`os.getenv` — which requires a **de-sanitized** DCS install (already the case for CTLD developers).
The trigger is **hardened** to fail explicitly (never silently) on the three failure modes.

### Final trigger snippet (inline in the DO SCRIPT action)

```lua
-- Load the developer's local CTLD.lua via CTLD_DEV_ROOT (DCS must be de-sanitized).
local root = os and os.getenv("CTLD_DEV_ROOT")   -- os absent = sanitized DCS
if not root then
  local msg = "[CTLD dev] os/CTLD_DEV_ROOT unavailable -- de-sanitize MissionScripting.lua and "
           .. "run 'setx CTLD_DEV_ROOT <repo>' then restart DCS. CTLD.lua NOT loaded."
  env.error(msg); trigger.action.outText(msg, 30)
  return
end
local path = root .. "/CTLD.lua"
local ok, err = pcall(dofile, path)
if not ok then
  local msg = "[CTLD dev] dofile(" .. path .. ") failed: " .. tostring(err)
  env.error(msg); trigger.action.outText(msg, 30)
end
```

## User Stories

- As a **CTLD developer**, I want the shared martyr to load *my* local `CTLD.lua` without editing the
  `.miz`, so I stop polluting git history and never leak a personal path into a shared branch.
- As a **new CTLD developer**, I want one documented setup step (`setx CTLD_DEV_ROOT`, restart DCS) to
  make the martyr work, so onboarding is a checklist, not tribal knowledge.
- As **any developer**, when my environment is wrong (sanitized DCS, missing var, bad path), I want the
  trigger to tell me on screen *why* CTLD did not load, so I don't debug a silent no-op.

## Implementation Decisions

- **Env var name = `CTLD_DEV_ROOT`, value = repo root**; the trigger appends `/CTLD.lua`. Consistent
  with the runner's `REPO_ROOT`, reusable if another repo file ever needs loading.
- **Inline snippet** in the DO SCRIPT action (not an embedded `DO SCRIPT FILE` bootstrap): the logic is
  frozen (load one file — YAGNI), and `DO SCRIPT FILE` would introduce an embed-vs-repo desync trap.
  The snippet is mirrored in the live-DCS testing page as the copyable reference.
- **Explicit failure, no fallback**: on any of the three failure modes, log `env.error` **and**
  `outText` (30 s) — no silent `lfs.writedir()` fallback that would load a surprise CTLD. `os and …`
  guards against a sanitized install where `os` is nil.
- **Messages in English** (deliverables-in-English rule).
- **Delete dead line (2)** `ctldLogPath` entirely. The real "enable CTLD.log" need is already covered
  on demand by `tests/dcs/dev/diag/diag_enable_ctld_log.lua` (path derived from `ctld.path`, no machine
  value). The file-logging mechanism itself is untouched (out of scope, and still used by
  `dcs-runtime-debug`).
- **Miz stays committed** (not gitignored): once generic, it is a shared asset. The one-shot re-save by
  the DCS editor will be a large binary diff **once**, then stable.
- **Execution split**: authoring (snippet, docs, skill, backlog) is AFK; the miz edit happens in the
  **DCS mission editor** (handles the nested escaping and the duplicated trigger structure safely) and
  is done by the developer on their own DCS, followed by in-game validation.

## Testing Decisions

- No busted tests, no rebuild (no `src/` change).
- In-game validation (manual, by the developer): with `CTLD_DEV_ROOT` set and DCS restarted, load the
  martyr → CTLD loads (an F10 menu appears). Negative check: unset var / sanitized DCS → the on-screen
  `[CTLD dev]` message appears and CTLD does not load.

## Out of Scope

- Removing or reworking CTLD's file-logging (`CTLD.log`) mechanism — still used by the
  `dcs-runtime-debug` workflow; a separate product decision.
- The `--inject-ctld` hot-reload path — already machine-independent, unchanged.
- `dcs-bridge.lua` embedding and the `127.0.0.1:7777` bridge config — no machine path, unchanged.
- Programmatic patching of the `.miz` binary — rejected in favour of the DCS editor (nested escaping +
  duplicated trigger make blind patching fragile).

## Further Notes

- **Consequence for `dcs-runtime-debug`**: its "CTLD log" section claims *"Requires a `ctldLogPath` set
  in the test `.miz`"* — made false by deleting line (2). Ticket 02 re-aligns it onto
  `diag_enable_ctld_log.lua` (on-demand injection), same-movement doc hygiene.
- **Proposed ticket split** (tracer-bullet):
  1. `01` — miz trigger snippet + editor edit + in-game validation (hybrid: AFK authoring + live DCS).
  2. `02` — docs: move the existing live-DCS page into `docs/developer/`, add the martyr build-loading
     section (EN+FR) + `dcs-runtime-debug` skill fix (AFK).
- **The security angle** the roadmap raised (leaking a personal path into `master`) is structurally
  eliminated: the committed miz no longer contains any machine path.
