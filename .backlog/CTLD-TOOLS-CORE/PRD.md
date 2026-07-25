# Lot CTLD-TOOLS-CORE — UI-agnostic tool core + ops/TUI demolition

Status: ✅ merged (PR #66)
Branch: `feature/ctld-tools-core` → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`).
ADR: [0011](../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md).
Lot **2 of 3** in the ctld-tools v2 program. Depends on lot 1 (the YAML contract).

## Problem Statement

The tool is built around the ops/diff abstraction retired by ADR 0011: an ops editor
(`editmodel.py`, ops logic in `gen-user`), a Textual TUI, a separate `reference.json` catalogue
slice, and (on FullGas's branch) a tkinter GUI. The new model needs a **UI-agnostic core library**
that reads/edits/validates a **complete** catalogue YAML — with no interface investment, so lot 3
can put a web layer on top without any business logic being written twice.

## Solution (this lot = logic only, no new UI)

**Demolition**
- Remove the ops model: `editmodel.py`, the ops compilation in `gen-user`, ops-oriented tests.
- Remove the Textual TUI (`ctld_tools/tui/*`) and do **not** port FullGas's tkinter UI.
- Retire `reference.json` + `gen-reference`, `gen-config` (YAML→Lua-table; the build now embeds the
  YAML string), `extract` (Lua→YAML, one-shot, historical), and `Reference.from_src`: the core reads
  the single default catalogue YAML (AA already baked in by lot 1). **Drop `lupa` from `pyproject`
  entirely** — nothing reads Lua any more.

**Core library (pure functions, no interface)**
- Load / edit / save a **complete** catalogue YAML (Parameters + Data), schema-driven from
  `CTLD_config_schema.yaml` (inherit FullGas's expanded schema + field metadata).
- `validate`: complete catalogue vs schema + datamine type set; **mixedSet consistency** (every AA
  "All crates" weight exists); clear report.
- **Version-gap detection**: compare a `configUser`'s authored version to the current catalogue
  version; compute the diff (new / changed / removed defaults) for a caller to present.
- Keep `miz` trigger injection and `datamine`. Keep the `typer` CLI only for what build/CI need
  (config embed, `validate`, `gen`); no CLI UX investment.

**Boundary rule (anti-duplication):** this lot ships a **library**; lot 3's web endpoints are thin
wrappers over it. If business logic would be written in lot 3, it belongs here.

## Definition of Done

- Ops/TUI/tkinter/`reference.json`/`gen-config`/`gen-reference`/`extract`/`from_src`/`lupa` code
  paths and dependency removed; package imports clean; ruff + mypy green; `python-quality` CI green.
- Core API: load/edit/save complete YAML, `validate` (schema + datamine + mixedSet), version-gap
  diff — all unit-tested without any UI.
- Build integration updated (config embed via YAML-string wrap; no generated Lua-table artifact).
- CHANGELOG `[Unreleased]`; ADR 0011 referenced.

## Out of scope

- Any web/front code, endpoints, exe packaging (lot 3).
- Runtime changes (lot 1).

## Tickets

- **01** — demolish the ops/TUI surface (editmodel/genuser/scaffold/tui + cli commands).
- **02** — complete-catalogue core: load/edit/save (schema-driven; port FullGas schema+metadata).
- **03** — `validate`: schema + datamine + mixedSet consistency.
- **04** — version-gap detection (diff configUser version vs current catalogue).
- **05** — retire `gen-config`/`lupa` + rewire build/CI (round-trip oracle via core-emitted JSON;
  i18n dict sync scans the YAML). The hard one.
