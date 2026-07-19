# CTLD Next — Release Testing Procedure

Testing is organized in six levels (L1 to L6).
L1 and L2 run automatically via GitHub Actions CI.
L3 to L5 require a live DCS session with the dcs-bridge Lua bridge injected and `dcs-serve` running.
L6 is purely manual (player + checklist).

Every L3–L5 scenario also carries a `-- @tier:` header (`auto` / `auto-check` / `human`) marking
whether it needs an AI agent or human in the loop at all. Most of L3 (`noPlayer/`) is `auto` or
`auto-check` and can be **driven headlessly** by `tools/integration-runner/run_scenarios.py`
instead of injecting each script by hand — see [Automation tiers](#automation-tiers) below.

For debug configuration and CTLD.log setup, see [Building & testing](building-and-testing.md).

---

## Loading your build into the test mission (martyr)

L3–L6 run against the shared test mission `missions/Test_CTLDNEXT_01.miz` (the "martyr"). It loads
`CTLD.lua` from a per-developer environment variable, so the committed `.miz` never carries a
machine-specific path. One-time setup on each developer's machine:

1. **De-sanitize DCS.** `os.getenv` is only available when the DCS Lua environment is not sanitized
   — re-enable `os` / `io` / `lfs` in `Scripts/MissionScripting.lua`. Without this the mission
   trigger fails with an explicit on-screen message and CTLD is not loaded.
2. **Set `CTLD_DEV_ROOT`** to your repository root, then **restart DCS**:

   ```
   setx CTLD_DEV_ROOT "D:\path\to\CTLD"
   ```

   `setx` persists the value in the Windows user registry (`HKCU\Environment`), so it survives
   reboots. The pitfall is **not** persistence but process inheritance: a **running DCS does not see
   the new variable** — close DCS (and its launcher) and reopen it. When in doubt, log off and on.
3. That is all — the martyr's MISSION START trigger loads `<CTLD_DEV_ROOT>/CTLD.lua`. No developer
   edits the `.miz`. After a `src/` change, rebuild `CTLD.lua` and reload the mission (`Shift+R`) so
   the trigger re-`dofile`s the fresh build.

The trigger is hardened to fail loudly (log + on-screen) on a sanitized install, an unset variable,
or a bad path. For reference, the exact snippet in the trigger is:

```lua
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

---

## Folder to level mapping

| Folder | Level | Execution context |
| --- | --- | --- |
| `tests/ci/unit/` | L1 | GitHub Actions — busted, no DCS |
| `tests/ci/functional/` | L2 | GitHub Actions — busted, no DCS |
| `tests/dcs/noPlayer/` | L3 | Developer local — DCS + dcs-bridge, no player slot |
| `tests/dcs/pilotPassive/` | L4 | Developer local — DCS + player in cockpit, script drives |
| `tests/dcs/pilotActive/` | L5 | Developer local — DCS + player takes F10 actions |
| `tests/manual_test_sequences.md` | L6 | Developer local — player, step-by-step checklist |

---

## Automation tiers

Independently of the L-level (which folder a scenario lives in), every scenario carries a
`-- @tier:` header telling you (or the runner) whether it needs an AI agent/human at all:

| Tier | Meaning | Can run headless? |
| --- | --- | --- |
| `auto` | A single injection returns the definitive verdict (`PASS`/`FAIL`/`ABORT`). No player, no polling, no judgment call. | Yes |
| `auto-check` | Resolves automatically via a real timer/`waitFor` or a re-injected step machine, within seconds — the scenario returns `STARTED`/`RUNNING` and the runner polls/re-injects `_SCN_<ID>_RESULT` until it resolves. No human/AI judgment. | Yes (fast) |
| `auto-slow` | No human either, but takes **minutes** to resolve — an AI helicopter flying a route to a pickup/dropoff zone, or a long internal timer chain (e.g. the JTAC drone ~13 min). Excluded from the fast `--headless` sweep; run explicitly with `--tier auto-slow --poll-timeout 900`, player just parked in a slot. | Yes (slow, on demand) |
| `human` | Needs a human: either a live player who must **fly** (`human (fly)`) or one who must **click an F10 item / make a visual judgment** the code never checks (`human (menu)`). dcs-bridge has no flight-control API. | No |
| `disabled` | Quarantined: code **and** mission are both correct, but the test can't complete for a reason outside CTLD (e.g. the DCS AI helicopter won't reliably land on a specific spot). Never run by a default sweep; reachable only via an explicit `--tier disabled`. Logic coverage lives in fast deterministic tests. | No (quarantine) |

The `pilotActive/`/`pilotPassive/` folders do **not** imply `human` — the tier reflects what a
scenario's code actually needs, checked per file, not its folder. A `CATCH-UP-PILOT-SCENARIOS`
audit found that of the ~34 scenarios once blanket-tagged `human`, only a handful truly need a human
(two menu-visual `human (fly)` checks, plus one deferred and one optional-manual); the large
majority drive AI helicopters or self-verify and are `auto-check`/`auto-slow`. See the
`integration-testing` skill for the full taxonomy and how each template defaults.

### How to run each tier — command + what's expected of you

Two dependency-free Python runners drive scenarios over `dcs-serve`'s REST API and read back the
verdict (no install step; both read `dcs-client.yaml`). Prerequisite for all of them: `dcs-serve`
running and the mission loaded with `dcs-bridge.lua` injected (see the top of this page).

| Tier | Command | What YOU do |
|---|---|---|
| `auto` | `python tools/integration-runner/run_scenarios.py --headless` | **Nothing.** Fully headless. (No slot needed.) |
| `auto-check` | same `--headless` sweep (covers `auto` + `auto-check`) | **Be parked in a BLUE slot** (UH-1H) — some read your unit's position/group. No flying, no clicking. |
| `auto-slow` | `python tools/integration-runner/run_scenarios.py --tier auto-slow --poll-timeout 900` | **Be parked in a BLUE slot**, then wait — each needs minutes of AI-helicopter flight. Excluded from `--headless` on purpose. Optional (logic also covered by the `noPlayer` `aiTransport_featureT/U` tests). |
| `human (fly)` | `python tools/integration-runner/run_manual_scenario.py --scenario <name>` | **Fly the aircraft** as the terminal instructs (take off, land, reposition). The runner mirrors each step's in-game instructions to your terminal. |
| `human (menu)` | `python tools/integration-runner/run_manual_scenario.py --scenario <name>` | **Click F10 menu items / make a visual check** as instructed (no flying). |

Notes:
- A **full headless sweep** (recommended before a release) is
  `python tools/integration-runner/run_scenarios.py --headless --inject-ctld --reset-before-each`
  — the `--reset-before-each` clears cross-scenario CTLD state (see below) so back-to-back runs
  don't contaminate each other. Writes a JUnit report (`test-results.xml`).
- Target a subset with `--scenario <substring>` (e.g. `--scenario F-178`) or `--dir noPlayer`.
- `run_manual_scenario.py` recovers from a crash: just re-run the same command (it resets the
  scenario's own state first). It also prints an elapsed `[mm:ss]` stamp + a heartbeat so a long
  scenario is visibly alive.
- See `tools/integration-runner/README.md` for the full flag reference and the tier/`RUNNING`
  internals.

#### Cross-scenario state contamination

Scenarios share CTLD's runtime singletons (`PlayerManager`, `MenuManager`, JTAC registry). Some
leave residue (phantom players, a wiped player menu, orphan JTACs) that would make a *later*
scenario abort — running one alone is fine, a back-to-back sweep accumulates it. `net.load_mission`
isn't available on a DCS client, so the mission can't be reloaded from Lua. `--reset-before-each`
injects `tests/dcs/_reset_state.lua` before each scenario to restore a clean player/menu + JTAC
baseline without a reload. If a scenario ever needs a deeper reset than that, reload the mission
manually (Shift+R).

---

## Architecture overview

```text
RELEASE
  |
  +- L1  CI busted unit        tests/ci/unit/*_spec.lua          ~105 tests  (automatic)
  +- L2  CI busted functional  tests/ci/functional/*_spec.lua    ~45 tests   (automatic)
  |
  +- L3  DCS noPlayer          tests/dcs/noPlayer/               ~136 scripts (developer, before push)
  |         U-xxx  unit-level dcs-bridge scripts
  |         F-xxx  targeted functional dcs-bridge scripts
  |         scenario_*  multi-step integration scenarios
  |
  +- L4  DCS pilotPassive      tests/dcs/pilotPassive/           ~30 scripts  (developer, before push)
  |         player in cockpit, script drives all steps automatically
  |
  +- L5  DCS pilotActive       tests/dcs/pilotActive/            2 scripts    (developer, before push)
  |         player in cockpit AND must take F10 actions between steps
  |
  +- L6  Manual sequences      tests/manual_test_sequences.md    4 MT-xx      (developer, new features only)
```

---

## Release order

```text
Modify src/
    |
[LOCAL] L3 noPlayer  -- inject relevant F-xxx + scenario_* for modified module
    | (PASS)
[LOCAL] L4 pilotPassive  -- if feature touches player flow (menus, spawns, effects)
    | (PASS)
[LOCAL] L5 pilotActive  -- if feature modifies an F10 menu visible to the player
    | (PASS, or skip if not applicable)
git push  ->  CI L1/L2 runs automatically
    | (CI green)
PR  ->  merge to master
    |
git tag vX.Y  ->  CI Release job builds and publishes CTLD.lua
```

> **Rule:** L3 to L5 must pass **before** the push. CI (L1/L2) uses DCS stubs and cannot
> detect real-DCS regressions. A green CI with a failing L3 means the code is broken
> without CI knowing it.
>
> **Exception:** documentation, comments, non-functional refactors may be pushed without L3 to L5.

---

## L1 — CI busted unit (automatic)

**Who:** GitHub Actions.
**When:** every push to `master` or `feature_*`, every PR.
**Scripts:** `tests/ci/unit/*_spec.lua` — 21 files, ~105 tests.
**Runner:** `busted tests/ci/` (Job 3 in `.github/workflows/ci.yml`).

Scope: Config, EventDispatcher, Zones, Crates, Troops, JTAC, Menu, Utils, i18n.
All DCS API calls replaced by stubs in `tests/ci/helpers/dcs_stubs.lua`.

---

## L2 — CI busted functional (automatic)

**Who:** GitHub Actions.
**When:** same triggers as L1.
**Scripts:** `tests/ci/functional/*_spec.lua` — 8 files, ~45 tests.

| Spec file | Tests |
| --- | --- |
| `troop_manager_spec.lua` | embarkFromTroopZone, disembark, returnToTroopZone, embarkFromField |
| `jtac_manager_spec.lua` | spawnJTAC, setJTACInTransit, requestSmoke, killJTAC |
| `parachute_spec.lua` | parachuteCrates/Troops/Vehicles, slingload hover/release/cut |
| `utils_spec.lua` | getCentroid, calcDropPosition, getSpawnObjectPositions |
| `config_spec.lua` | YAML override, singleton reset, i18n fallback/FR/ES/KO |
| `mark_ids_spec.lua` | Global mark ID counter monotonicity |
| `vehicle_spec.lua` | findLoadableVehicles, loadVehicle, unloadVehicle, _spawnUnpacked |
| `troop_multi_spec.lua` | Multi-group transit, disembarkAll/Index, _menuCheckCargo |

> Note: `tests/dcs/noPlayer/F-xxx.lua` and `U-xxx.lua` are dcs-bridge injection scripts (L3),
> not busted specs. They are not picked up by CI (no `_spec` suffix).

---

## L3 — DCS noPlayer (developer, before push)

**Who:** developer.
**When:** before every push that modifies `src/`.
**How:** inject scripts into a running DCS mission. No player slot required.
**Success:** `fail=0` in result line + no `[FAIL]` in `tests/dcs/CTLD.log`.

> Most of L3 is `auto`/`auto-check` tier and can run headlessly via
> `tools/integration-runner/run_scenarios.py --headless` (see [Automation tiers](#automation-tiers))
> instead of injecting the files below by hand.

### L3a — Targeted tests (U-xxx / F-xxx)

Inject the files covering the modified module:

| Modified module | Files to inject |
| --- | --- |
| `CTLD_troop.lua` | F-033 to F-036, F-059, F-060, F-140 to F-146 |
| `CTLD_jtac.lua` | F-037 to F-040, F-110 to F-112 |
| `CTLD_crate.lua` | F-027 to F-032, F-057, F-058, F-061 to F-071, F-120 to F-123 |
| `CTLD_vehicle.lua` | F-015 to F-020, F-120 to F-123 |
| `CTLD_core.lua` (AI) | F-133, F-134, F-176 to F-182 |
| `CTLD_zone.lua` | F-003 to F-005 |
| `CTLD_recon.lua` | F-009 to F-011, F-115 to F-119 |
| `CTLD_config.lua` / i18n | F-101 to F-105 |
| `CTLD_menu.lua` | U-045 to U-053, U-057 to U-066 |

### L3b — Integration scenarios

Run scenarios matching the modified feature:

| Feature area | Scenario |
| --- | --- |
| AI transport / stocks | `aiTransport_featureT_*.lua`, `aiTransport_featureU_*.lua` |
| JTAC toggle / corrections | `scenario_jtac_toggle_lasing.lua`, `scenario_jtac_spot_corrections.lua` |
| Crate menu / load | `scenario_b3_load_crate_from_menu.lua`, `scenario_crate_menu_flight_visibility.lua` |
| Vehicle transport | `scenario_fq_vehicle_whole_transport.lua`, `scenario_mt05_crate_vehicle.lua` |
| AI zones | `scenario_fr_ai_zones.lua` |
| Extractable groups | `scenario_fo_extractable_groups.lua` |
| Countryside FARP spawn | `scenario_farp_countryside_spawn.lua` |

---

## L4 — DCS pilotPassive (developer + player slot, before push)

**Who:** developer in a BLUE transport slot (UH-1H or equivalent).
**When:** before push, for player-visible feature changes.
**How:** take the slot, inject the scenario, watch — no F10 action required.
**Success:** all steps report `[PASS]`, visual checks match expected.

Key scenarios:

| Scenario | Feature |
| --- | --- |
| `scenarioTroopsFullCycle_v2.lua` | Troops + JTAC full lifecycle |
| `scenario_multigroup_transport.lua` | Multi-group transport |
| `scenario_fob_scene.lua`, `scenario_p2_fob_parachute.lua` | FOB scene + parachute |
| `scenario_p3_csfarp_parachute.lua`, `scenario_p4_metal_farp.lua` | FARP scenes |
| `scenario_farp_repack.lua`, `scenario_warehouse_cycle.lua` | FARP repack + warehouse |
| `scenario_feature_f_recon_farp.lua` | RECON FARP/FOB layer |
| `scenario_feature_k_jtac_vehicle.lua` | JTAC vehicle in-transit |
| `scenario_ai_troops.lua` + `scenario_mt08_ai_vehicle.lua`..`scenario_mt14_ai_aa_system.lua` | AI transport battery (`auto-slow`; `mt08`/`mt14` are `disabled`/quarantined — DCS AI landing) |

---

## L5 — DCS pilotActive (developer + player F10 actions, before push)

**Who:** developer in a BLUE transport slot — must execute F10 menu actions on demand.
**When:** before push, only when F10 menu structure or visibility changes.

| Scenario | What the player must do |
| --- | --- |
| `scenario_crate_menu_sol_vol_visual.lua` | Confirm Crate Commands menu on ground / in flight / after landing |
| `scenario_troop_menu_sol_vol_visual.lua` | Confirm Troop Commands menu on ground / in flight / after landing |

---

## L6 — Manual sequences (developer, new features only)

Step-by-step checklists in `tests/manual_test_sequences.md`. No script — pure observation.

| Sequence | Feature | Trigger |
| --- | --- | --- |
| MT-01 | Multi-group troop transport + disembark menu | Any troop transport change |
| MT-02 | Whole-vehicle load / unload / parachute | Vehicle transport change |
| MT-03 | Multi-vehicle load / unload / parachute | Vehicle capacity or multi-load change |
| MT-06 | RECON FARP/FOB layer | RECON or CTLDStaticWatcher change |

---

## Summary — effort per release

| Level | Who | When | Approx. effort |
| --- | --- | --- | --- |
| L1 CI unit | GitHub Actions | Automatic | 0 |
| L2 CI functional | GitHub Actions | Automatic | 0 |
| L3a F-xxx targeted | Developer | Before push — impacted modules only | ~5 min/module |
| L3b scenario noPlayer | Developer | Before push — impacted features only | ~10 min |
| L4 pilotPassive | Developer + cockpit | Before push — player-visible features | ~20 min |
| L5 pilotActive | Developer + cockpit | Before push — F10 menu changes only | ~10 min |
| L6 Manual MT-xx | Developer + cockpit | New player-visible features | ~15 min/MT |

---

## Pre-release checklist

Before tagging `vX.Y`:

- [ ] All CI jobs green on `master` (lint, build, busted).
- [ ] Any new `src/` file added to `tools/build/listToMerge.txt`.
- [ ] L3 passed — `python tools/integration-runner/run_scenarios.py --headless` (or targeted
      per-module injection) for all modules modified since last tag.
- [ ] L4 passed for all player-visible features modified since last tag.
- [ ] L5 passed if any F10 menu structure changed.
- [ ] This page updated (tier taxonomy / scenario list) if a scenario or tier was added.
- [ ] `migration/MODERNIZATION-PLAN.md` feature statuses up to date.
- [ ] `docs/pilot/` and `docs/mission-maker/` updated if any user-visible behavior changed.
