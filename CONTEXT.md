# CONTEXT — CTLD ubiquitous language

Canonical glossary of the CTLD domain. Keep terms consistent across code, tests and docs. New or
redefined terms are added here in the same move as the decision that introduces them (see
`docs/agents/domain.md`).

## Core concept

- **CTLD** — Combined Transport and Logistics Dispatcher: a DCS World mission script letting
  helicopter/transport crews move troops, vehicles and supply crates around the battlefield. This
  project is its modular OOP rewrite (targeting **v2.0.0**): source in `src/`, merged into the
  single deliverable `CTLD.lua`.
- **Legacy / `source`** — the original monolithic v1 `CTLD.lua` in `migration/source/`, kept as the
  immutable functional-parity reference.
- **Mission Maker (MM)** — the person who creates a DCS World mission using CTLD: configures zones,
  aircraft types, crate catalogues and troop templates. Historically hand-edited in
  `CTLD_userConfig.lua`; the target authoring surface is a validated YAML processed by
  [ctld-tools](#configuration--authoring), which generates the Lua. Target proficiency: comfortable
  with DCS ME triggers, not necessarily a Lua developer.

## Architecture terms

- **Class framework** — `src/core/class.lua`: minimal OOP (`class(base)` → `:new()` calling
  `init()`), inheritance via metatables.
- **Manager + Entity** — dominant pattern: an Entity class (single instance) plus a Manager
  singleton (`getInstance()` / `get()`) per domain (troops, crates, JTAC, zones…).
- **CoreManager** — the orchestrator: internal pub/sub of ~38 CTLD events, single bridge to DCS
  events, player tracking without MIST, init sequence (INIT-A/B/C).
- **`ctld.gs("param")`** — the only sanctioned config accessor.
- **`ctld.utils`** — in-house replacement for MIST (math/vectors/geometry, scheduler, logging).
- **Legacy API** — thin delegate wrappers (`src/legacy/legacy_api.lua`) keeping v1 missions working.

## Configuration & authoring

- **ctld-tools** — a standalone tool (a Python package; distributed to MMs as a self-contained
  `ctld-tools.exe`) that validates and generates CTLD configuration from YAML. It embeds the
  default-config reference and the datamined DCS type set to validate entries offline. The `.exe` is
  a release artefact for MMs; the build/CI invoke the Python package directly. Exact filenames are
  pinned per PRD. See ADR 0009.
- **Config reference (`ctld-config`)** — the engine's default configuration, held as **YAML as the
  single source of truth** (sectioned MM-facing vs advanced). The build regenerates the Lua consumed
  by `CTLDConfig:load()`; the hand-edited Lua defaults block is retired.
- **User config (`user-config`)** — the MM's YAML: a list of **operations** (`add` / `delete` /
  `edit`) over the default catalogue, validated against the config reference and compiled by
  ctld-tools into `ctld.userSetup` helper calls (the runtime API from ADR 0008).
  _Avoid_: describing it as a full declarative catalogue — it is a diff, not a replacement.

## Gameplay domain

- **Troop** — an infantry group loaded/unloaded by a transport; state machine
  (loaded → deployed → field-loaded → extracted).
- **Crate** — a supply crate that can be spawned, slung, dropped by parachute, and **packed** /
  **unpacked** into a static or vehicle.
- **Pack / unpack** — the sanctioned verbs for crate assembly/disassembly. The old term
  **"repack" is banned**.
- **Vehicle transport** — carrying a whole vehicle (spawn/load/unload/parachute/pack).
- **Slingload (virtual)** — CTLD's simulated sling-loading, independent of DCS native sling.
- **JTAC** — Joint Terminal Attack Controller: lases targets, may be drone-based (orbit), with
  target deconfliction and a laser pool.
- **Beacon** — radio beacon (VHF/UHF/FM) attached to a deployed asset.
- **Recon** — line-of-sight detection that renders persistent F10-map markers (FARP/FOB layers).
- **FOB / FARP** — Forward Operating Base / Forward Arming and Refuelling Point built via crates.
- **Scene** — a pre-defined multi-step build (FARP, FOB, minefield…) run by the SceneManager. A
  scene's source is **load-position-independent**: the same file works whether merged into `CTLD.lua`
  or loaded from a mission-start trigger after CTLD.
  - **Built-in scene** — a scene merged into the `CTLD.lua` deliverable (via `listToMerge.txt`).
  - **Plugin scene** — a scene distributed by the separate **CTLD_plugins** repo, built to a single
    loadable `.lua` and loaded by a mission-start trigger *after* CTLD. One plugin = one scene
    (plus its optional Lua deps). "Plugin" is a distribution vehicle, not a gameplay concept.
- **AA system** — multi-crate air-defence assembly (HAWK, NASAMS, KUB, BUK, Patriot, S-300).

## Zones

- **TRZ_** — troop zone. **LGZ_** — logistic zone. **WPZ_** — waypoint zone. **EXZ_** — extraction
  zone. **AIZ_** — AI-transport zone (auto pickup/dropoff).

## Testing terms

- **Integration test** — a test injecting Lua into a live DCS mission (the practice previously
  called "recette", a banned French term).
- **Test level** — the execution context of a test, L1 to L6:

  | Level | Folder | Who drives |
  |-------|--------|------------|
  | L1 | `tests/ci/unit/` | CI — busted, no DCS |
  | L2 | `tests/ci/functional/` | CI — busted, no DCS |
  | L3 | `tests/dcs/noPlayer/` | script only, no player slot |
  | L4 | `tests/dcs/pilotPassive/` | script drives, player parked in cockpit |
  | L5 | `tests/dcs/pilotActive/` | player executes F10 actions |
  | L6 | `tests/manual_test_sequences.md` | player + manual checklist, no runner |

- **Tier** — a scenario's automation level, declared `-- @tier: <value>` in each scenario file.
  Values:
  - `auto` — single injection returns an immediate verdict; fully headless.
  - `auto-check` — resolves automatically via timers / `waitFor` / re-injection within seconds;
    headless.
  - `auto-slow` — no human needed, but takes minutes (AI-heli flight or long timer chain);
    excluded from the headless sweep, run explicitly with `--tier auto-slow`.
  - `human` — requires a live pilot: `human (fly)` (must fly/land) or `human (menu)` (F10 click
    or visual judgment the code cannot verify). _Avoid_: `ia` (old name, banned).
  - `disabled` — quarantined: code and mission are correct but the scenario cannot reach a
    verdict due to an external blocker (DCS AI pathfinding, missing mod). Never run by default;
    reachable only via `--tier disabled`. See ADR 0006.
- **Headless sweep** — running all `auto` + `auto-check` scenarios via
  `run_scenarios.py --headless --reset-before-each`, player parked in a BLUE slot, no human
  input required. _Avoid_: `--no-ai` (old flag name, banned).
- **Runner** — the Python harness: `run_scenarios.py` (batch, headless/auto-slow) and
  `run_manual_scenario.py` (one `human`-tier scenario at a time, interactive).
  _Avoid_: `run_ia_scenario.py` (old name, banned).
- **dcs-bridge** — VEAF-dcs-bridge: the live Lua injection bridge (`exec_lua`), replacing Witchcraft.
