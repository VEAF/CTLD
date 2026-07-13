# Integration runner — dcs-bridge scenario runners

`run_scenarios.py` runs `tests/dcs/` integration scenarios against a live DCS mission without
an AI agent in the loop, for scenarios that don't need one (`auto`/`auto-check` tier — see the
`integration-testing` skill for the full `@tier` taxonomy).

`run_ia_scenario.py` does the same for one `ia`-tier scenario at a time (`pilotActive`/
`pilotPassive`) — most of those don't need AI *judgment* either, just a live pilot; see
[Interactive `ia` scenarios](#interactive-ia-scenarios-run_ia_scenariopy) below.

**Dependency-free**: stdlib only (same convention as `tools/dcs-data/gen_dcs_types.py`). No
`pip install`, no venv — any system Python 3.9+ runs it directly.

## Prerequisites

- `dcs-serve` running, connected to a live DCS mission with the dcs-bridge Lua script injected.
- `dcs-client.yaml` at the repo root (gitignored) with `host`/`port`/`api_key` matching
  `dcs-serve.yaml` — the runner reads the same file the MCP server uses.

## Usage

```bash
# See what would run, no network calls
python tools/integration-runner/run_scenarios.py --list

# Run every auto / auto-check scenario (the "no AI needed" set), inject CTLD.lua first
python tools/integration-runner/run_scenarios.py --no-ai --inject-ctld

# Target a subset
python tools/integration-runner/run_scenarios.py --dir noPlayer --tier auto
python tools/integration-runner/run_scenarios.py --scenario F-178

# Heavy AI-flight battery (auto-slow): no human, but minutes of real AI-heli flight each --
# excluded from --no-ai on purpose. Run explicitly with a generous timeout (player parked in a
# BLUE slot for the pos/country lookups):
python tools/integration-runner/run_scenarios.py --tier auto-slow --poll-timeout 900

# Custom report path / polling behaviour
python tools/integration-runner/run_scenarios.py --no-ai --junit-out out/results.xml \
    --poll-interval 1 --poll-timeout 30
```

Run `python tools/integration-runner/run_scenarios.py --help` for the full flag reference.

## Scope boundary — `RUNNING` vs `STARTED`

- `STARTED` scenarios (async, resolved by the scenario's own timers/`waitFor`) are polled
  automatically — the result var alone tells you when it's done.
- `RUNNING: step=N ...` scenarios need the **full source re-posted** to advance their internal
  step machine, not just a poll of the result var. Both runners handle this the same way now:
  re-inject on `RUNNING`, same as polling on `STARTED`.
  - If that re-injection alone is enough to make progress (a timed delay between steps, no
    physical action needed), the scenario belongs in `auto`/`auto-check` and `--no-ai` runs it
    headlessly — re-injecting on a timer needs no human.
  - If a **physical DCS-side action** has to happen between injections (an aircraft landing in
    a zone, an F10 click), the scenario stays tagged `ia` so `--no-ai` never selects it —
    re-injecting alone can't make that physical action happen. Use `run_ia_scenario.py` for
    those; there's a human present to do the physical part between its re-injections.
  - **Don't assume `RUNNING` ⇒ `ia`** — check what actually gates the next step before tagging.
    `scenario_jtac_crate_pack.lua`/`scenario_feature_k_jtac_vehicle.lua` used `RUNNING` but only
    ever waited on a timer, no physical action; they were mistagged `ia` by the folder-default
    rule and are now `auto-check`. If a `RUNNING` scenario that genuinely needs a physical
    action is ever reached by `run_scenarios.py` anyway (e.g. an explicit `--tier ia`),
    re-injecting just spins harmlessly until `poll_timeout` and reports `FAIL` — no crash, just
    a plainer message than before.

### The `auto-slow` tier — no human, but minutes of AI flight

A third no-human tier sits between `auto-check` and `ia`: scenarios that need an **AI helicopter**
(not a human) to physically fly a multi-waypoint route to a pickup/dropoff zone before the next
step's check can pass (the `heliai_*`-driven MT-07..14 + `scenario_ai_troops`). They resolve with
no pilot and no F10, so they're not `ia` — but each takes minutes of real AI flight, so the 2s
re-inject loop of a `--no-ai` sweep would spam and stall the whole batch on one scenario. Tagged
`auto-slow` and **excluded from `--no-ai`**; run them deliberately with `--tier auto-slow
--poll-timeout 900` (player parked in a BLUE slot). Their core logic is already covered fast and
headlessly by the `noPlayer` unit-level `aiTransport_featureT/U` tests (F-176..182), so `auto-slow`
is the heavier end-to-end complement, not the only coverage.

## Interactive `ia` scenarios (`run_ia_scenario.py`)

`pilotActive`/`pilotPassive` scenarios are tagged `ia` because dcs-bridge can't fly an
aircraft — but most of them self-verify (same `checkMenuExpected()`-style logic as `auto`
scenarios) and don't need an AI to *judge* anything. `run_ia_scenario.py` runs one of these
from your own terminal, no AI agent needed for the injection/polling loop:

```bash
python tools/integration-runner/run_ia_scenario.py --scenario scenario_troop_menu_sol_vol_visual
python tools/integration-runner/run_ia_scenario.py --scenario crate_menu_sol_vol_visual
```

It injects the scenario, mirrors its in-game instruction text to the terminal (no alt-tabbing
to read `trigger.action.outText`), and polls `_SCN_<ID>_RESULT` to a terminal verdict. Answer
F10 prompts in DCS as instructed; fly as directed; the script reports PASS/FAIL when done.
Handles both async patterns transparently: `STARTED` scenarios are polled (they resolve on
their own); `RUNNING: step=N ...` scenarios (see [Scope boundary](#scope-boundary--running-vs-started)
above) get the full source re-posted each cycle instead, since that's what actually advances
their internal step machine — a real pilot is present to do the physical part in between.

**Progress feedback.** Every printed line carries an elapsed `[mm:ss]` stamp, and a heartbeat
line prints every ~30s even when nothing changed (`--heartbeat` to tune) — so a long scenario
(e.g. the JTAC drone's ~13 min of internal timers) is visibly alive, not hung. Each step's
in-mission instruction text is echoed to the terminal as it changes, so you see what the
scenario is telling the player at each stage without looking at the F10 screen.

**Crashed mid-test?** Just re-run the exact same command. Every run first calls the
scenario's `_SCN_<ID>_CLEANUP` global (if it exposes one — both `_template_pilotActive.lua`
and `_template_pilotPassive.lua` do) to cancel any stuck timer and clear its running-guard
before re-injecting — no "already active, restart DCS" dead end, no partial state to reason
about.

Scenarios needing genuine visual/subjective judgment (e.g. "menu looks identical after a
second refresh") still prompt a human, but as F10 clicks in DCS same as any other human
step — this script doesn't add a separate terminal-input path for that, it just removes the
need for an AI to drive the loop.

### What `ia` actually asks of you

Not every `ia`-tagged scenario needs the same thing from a human, and the folder-default rule
(`pilotActive/`/`pilotPassive/` → always `ia`) doesn't tell you which. When retagging or
authoring a scenario, note in the `@tier` comment which kind it is:

- **slot only** — needs a BLUE unit connected for its position/groupId, nothing else (no
  flight-state check, no F10 wait). This isn't really `ia` at all — retag it `auto`/`auto-check`
  (see the mistagging example in [Scope boundary](#scope-boundary--running-vs-started) above).
- **`ia (menu)`** — stationary, but needs an F10 click or a visual judgment call (e.g. F-046,
  F-047).
- **`ia (fly)`** — needs real piloting: takeoff, landing, flying to a zone (e.g. `scenario_crate_
  menu_sol_vol_visual.lua`, `scenario_troop_menu_sol_vol_visual.lua`).

This is a plain-text qualifier in the comment, not a new value the tooling parses — `-- @tier:
ia (fly)` still matches `ia` for tier filtering (`TIER_RE` only captures the token right after
`@tier:`). It exists so a human scanning a ticket's scenario list knows what to expect before
starting: whether to expect to fly, just click, or nothing at all.

## Legacy relics

`tests/dcs/noPlayer/` still contains ~194 dead FullGas scenarios predating the `@tier`
convention (tracked as `CLEANUP-LEGACY-DCS-TESTS`). Discovery skips any file with no valid
`-- @tier:` header rather than failing — you'll see a one-line summary
(`Skipped N untagged file(s)...`); pass `--show-skipped` to list them.

## Tests

```bash
python -m unittest discover -s tools/integration-runner -p "test_*.py"
```

Covers all pure logic (tier extraction, verdict parsing, filtering, polling state machine,
JUnit XML shape, config reading) without needing a live `dcs-serve`. The one thing intentionally
untested here is the actual HTTP call (`urllib.request` to `/api/exec`) — exercising that needs
a real or mocked `dcs-serve`, out of scope for this lot.
