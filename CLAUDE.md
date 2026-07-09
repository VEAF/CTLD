# CTLD — Claude Code Instructions

> CTLD is a modular, testable rewrite of the CTLD (Combined Transport and Logistics
> Dispatcher) script for DCS World. Pure Lua 5.1 source in `src/` is merged into a single
> deliverable `CTLD.lua` by a PowerShell build. Tooling (build, test runner, docs) may use
> PowerShell / Python / Node; **only `CTLD.lua` must be pure Lua 5.1**.

## Language

- Deliverables (code, comments, specs, commits, PRs) in **English**. Published docs are bilingual
  **EN (default) + FR**. No FR/EN mixing within a sentence.

## Behavior (surgical mode)

- **Surgical**: never modify adjacent code/comments/formatting unrelated to the request; no
  opportunistic refactor.
- **Simplicity**: minimum code necessary, no speculative abstractions.
- **Zero assumptions**: if a spec is ambiguous or missing, STOP and ask. Never invent.
- **Legacy parity**: `migration/source/` (the original monolithic `CTLD.lua`) is the functional
  reference and is **immutable**. Any `src/` change must preserve identical in-game behavior
  unless a deviation is explicitly requested.

## Code quality

- **Lua 5.1 only** — no 5.2+ syntax (`goto`, `<const>`, `table.move`, `utf8.*`, `math.type`…).
  Enforced by CI `lua-lint` (`luac5.1 -p`).
- **luacheck** `--config .luacheckrc src/` must be clean (rely on CI if not installed locally).
- **Build**: `powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1` → `CTLD.lua`
  in UTF-8 without BOM. `CTLD.lua` is **generated — never hand-edit**; rebuild after any
  `src/` change.
- **TDD**: write a failing busted test first, make it pass, refactor. New/changed logic ships with
  tests. Coverage gate is a ratchet — it only ever goes up.

## Git flow

- Work on `feature/*` or `fix/*` from `develop`; never commit directly to `develop` or `master`.
- One branch / one PR per lot. Conventional Commits in English.

## Backlog

- `.backlog/` is the single source of truth (one dir per lot: `PRD.md` + `tickets/`;
  `.backlog/README.md` = index). Lots closed >3 days → `.backlog/archive/<LOT-ID>.md`.
- Never create a separate todolist file (TodoWrite is intra-session only).

## Default workflow

Sync (`git pull --ff-only` on `develop`) → create lot in `.backlog/` → branch → implement + tests
(TDD) + rebuild if `src/` changed + update `docs/` → `busted tests/ci/` → luacheck → `CHANGELOG.md`
`[Unreleased]` → commit + push → PR to `develop` → address review/CI → merge → back to `develop`.
If the user must test manually in DCS, stop and wait for explicit approval before continuing.

## CTLD conventions

- New OOP classes only in `src/` (Manager + Entity pattern via `src/core/class.lua`).
- Config access only via `ctld.gs("param")` (never `config:getSetting()`).
- DCS unit/type/weapon data: use the **datamine dataset** (`github.com/Quaggles/dcs-lua-datamine`),
  more accurate than Hoggit — never assume an API/type without verifying.
- "repack" is banned — use **"pack"** everywhere.

## Layout

- `docs/` = published site by role (`pilot/`, `mission-maker/`, `developer/`), mkdocs EN+FR.
- `dev/` = internal dev artifacts (`dev/adr/`, `dev/agents/`), not published.

## DCS integration testing

Inject Lua into a live mission via **VEAF-dcs-bridge** (`dcs-client mcp`, `exec_lua`). Scenarios
carry a tier header `-- @tier: auto | auto-check | ia`. New scenarios from
`tests/dcs/_template_scenario.lua`. Use the `integration-testing` skill for the injection loop
and the scenario return contract; for runtime/in-game debugging use the `dcs-runtime-debug` skill.

## Bash

All Bash commands are permanently authorized. Never block work waiting for approval.

## Agent skills

- Issue tracker: `dev/agents/issue-tracker.md` · Triage labels: `dev/agents/triage-labels.md`
  · Domain (`CONTEXT.md` + `dev/adr/`): `dev/agents/domain.md`.
