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
- **Scene** — a pre-defined multi-step build (FARP, FOB, minefield…) run by the SceneManager.
- **AA system** — multi-crate air-defence assembly (HAWK, NASAMS, KUB, BUK, Patriot, S-300).

## Zones

- **TRZ_** — troop zone. **LGZ_** — logistic zone. **WPZ_** — waypoint zone. **EXZ_** — extraction
  zone. **AIZ_** — AI-transport zone (auto pickup/dropoff).

## Testing terms

- **Integration test** — a test injecting Lua into a live DCS mission (the practice previously
  called "recette", a banned French term).
- **Tier** — a scenario's automation level, tagged `-- @tier: auto | auto-check | ia`
  (deterministic no-AI / unattended-with-AI-check / AI-piloted).
- **Runner** — the Python harness replaying `auto` scenarios via VEAF-dcs-bridge, no AI.
- **dcs-bridge** — VEAF-dcs-bridge: the live Lua injection bridge (`exec_lua`), replacing Witchcraft.
