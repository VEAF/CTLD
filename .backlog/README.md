# Backlog — CTLD

Local markdown backlog. One lot = one directory `<LOT-ID>/` (`PRD.md` + `tickets/`). This file is
the hand-maintained index. See `dev/agents/issue-tracker.md` for conventions and
`dev/agents/triage-labels.md` for the `Status:` vocabulary.

## Program — re-tooling CTLD on the VMCT model

The codebase is mature (v2.0.0). This program installs a professional process/tooling layer around
it and migrates DCS integration testing from Witchcraft to VEAF-dcs-bridge. PRDs and tickets are
authored **per lot, when the lot is started** (not in batch).

### Active lots

| Lot | Status | Description | Branch |
|-----|--------|-------------|--------|
| `DOC-README-CLEANUP` | ✅ merged (PR #21) | Fix README title, restructure Crate Operations sub-sections, relocate AA System Construction, replace Developer Guide with Documentation links. | — |
| `CATCH-UP-PILOT-SCENARIOS` | ✅ pending merge | Ran the never-executed `pilotPassive`/`pilotActive` scenarios. Audit found the "34 `ia`" was almost all mistagged: 66/66 now pass in a headless sweep (`--no-ai --reset-before-each`), real pilot burden ≈ 2 short menu flights (both PASS). Fixed a pile of test-harness defects + cross-scenario contamination (soft reset `_reset_state.lua`), + one product fix (`refreshMenuSection` flight-state override). Optional remainders: `auto-slow` AI battery (covered by F-176..182), mt16/warehouse, L6 manual (ticket 08). | test/catch-up-pilot-scenarios |
| `TOOLING-TEST-TAXONOMY` | ✅ merged (PR #29) | Formalise the test taxonomy post CATCH-UP-PILOT-SCENARIOS: update `CONTEXT.md` (tiers `human`/`auto-slow`/`disabled`, L1–L6 levels, headless sweep), create ADR 0006 (`disabled` pattern), fix mt08/mt14 Land waypoint to unblock `auto-slow`, fix stale `recette/` paths in MT-06. MT-08 PASS 12/12, MT-14 PASS. | — |
| `FIX-AI-C2-BUGS` | ✅ merged (PR #30) | Two bugs in the AI transport C2 (virtual stock) path: wrong activation guard when a physical vehicle is weight-rejected (Bug 1), and invalid typeName `M1025 HMMWV Armament` in example config causing silent Leopard-2 spawn (Bug 2a/2b). MT-08B PASS 7/7. | — |
| `USERCONFIG-LOADING` | ✅ merged (PR #32) | Separate `CTLD_userConfig.lua` from the build merge: new `CTLD_bootstrap.lua` keeps the engine auto-start in the deliverable; userConfig delivered in `dist/` as a standalone MM template loaded before `CTLD.lua`. Zero breaking change. | — |
| `TEST-PLUGIN-POSTINIT` | ✅ merged (PR #31) | L3 `noPlayer` `auto` scenario (F-124) verifying the post-init plugin contract: `registerSceneModel` after init, `deferMenuSection` direct routing (not queued), `requiresCtld` soft-fail. PASS 7/7. | — |
| `TEST-TYPENAME-VALIDATION` | ✅ merged (PR #36) | Extend `CTLDTypeCollector.collect()` to cover `aiZones[*].vehicleStock`, `capabilitiesByType[*].loadableVehiclesRED/BLUE`, and `aiZones[*].vehicleTypes` — closing the CI type-linter gap exposed by the `M1025 HMMWV Armament` silent-spawn bug. | — |
| `FIX-LGZ-POLL-NIL-ISFLYING` | ⬜ ready | LGZ ground-position poll skips players with `_isFlying=nil` (never flown) — `== false` guard → `~= true`; regression test. Diagnosed via dcs-bridge 2026-07-19. | — |

### Planned lots

None. Future candidates → [`dev/roadmap.md`](../dev/roadmap.md).

### Delivered (socle, this program)

| Lot | Description |
|-----|-------------|
| `REPO-BOOTSTRAP` | New VEAF repo, clean history, Git Flow `develop`/`master` |
| `PROCESS-SCAFFOLD` | Lean `CLAUDE.md`, `.backlog/`, `CONTEXT.md`, `dev/agents/`, `dcs-runtime-debug` skill, history cleanup |
| `CI-REVAMP` ✅ | CI on `develop`, single build source, coverage ratchet (59%/61.56%), gitleaks, hygiene (PR #1). |
| `CONTEXT-ADR` ✅ | Retroactive ADRs 0001–0005 in `dev/adr/` (PR #4). |
| `CLAUDE-AUTOMATIONS` ✅ | Project hooks (block protected paths, luacheck-on-edit) + subagents lua51/parity (PR #5). |
| `DCS-DATAMINE-VENDOR` ✅ | Vendored DCS type set (not shipped) + offline config type linter (PR #6). |
| `RELEASE` ✅ | `release` skill + `release.yml` (tag `published-v*`); release job moved out of ci.yml (PR #7). |
| `DOC-MKDOCS` ✅ | mkdocs-material infra (i18n EN+FR, mike) + `docs.yml` → gh-pages live at veaf.github.io/CTLD (PR #8). |
| `DOC-TECH` ✅ | Bilingual `docs/developer/` consolidation (20 EN + 20 FR pages) + workflow page; old sources + `migration/specs/` removed (PR #11). |
| `DOC-USER-ROLES` ✅ | Bilingual role split of the user guide → `docs/pilot/` + `docs/mission-maker/` (19 EN + 19 FR pages); monolith removed (PR #12). |
| `DCS-BRIDGE-MCP` ✅ | Migrate DCS integration testing from Witchcraft to VEAF-dcs-bridge: `.mcp.json` + project-local venv, scenario return contract, 79 scenarios + 4 templates migrated, `integration-testing` skill, Witchcraft fully retired (PR #14). Uncovered ~194 dead FullGas relics → `CLEANUP-LEGACY-DCS-TESTS`. |
| `INTEGRATION-TEST-TAGS` ✅ | `-- @tier: auto\|auto-check\|ia` header on the 79 scenarios + 4 templates (43/2/34 split); fixed F-122's unresolved verdict found during the classification audit (PR #15). |
| `INTEGRATION-TEST-RUNNER` ✅ | Dependency-free `tools/integration-runner/run_scenarios.py`: discovers + tier-filters scenarios, drives them over dcs-serve REST, polls async ones, writes a JUnit report; `--no-ai` mode runs every `auto`/`auto-check` scenario headlessly. 31 stdlib unit tests. Closes the DCS-bridge triptych. |
| `REINTEGRATE-ORPHAN-TESTS` ✅ | Rebuilt coverage for the 46 features tested only by dead FullGas relics — 6 busted tickets (158 tests, green in CI) + 1 live-DCS ticket (3 scenarios: BCN 30/30, RCN 10/10, VEH 22/22). 10 relics were false orphans (already covered); 6 deferred to FullGas (`dev/fullgas-report.md`). PR #20. |
| `POST-FULLGAS-FIXES` ✅ | Applied FullGas's review answers: Feature Q whole-vehicle spawn regression, AI-zone stock validation rewrite, U-108 heliport probe fixes, F-117/F-118 recon fixes, `coord_farp-1` mission static, README doc touch-ups. First full live run against real DCS (27/45) surfaced 18 failures, 8 fixed here as a side effect — remaining 10 → `FIX-LIVE-DCS-FAILURES`. PR #22. |
| `FIX-LIVE-DCS-FAILURES` ✅ | Triaged the 10 (of 18) failures from the first live run (2026-07-10) not already fixed by `POST-FULLGAS-FIXES` — all 10 turned out to be cross-scenario state contamination, cleared by a mission reload (48/48 green, no src/test change). Also closed the L4 gap on Feature Q's whole-vehicle Request Equipment menu. PR #23. |
| `SCENE-PLUGINS` ✅ | Pluggable scenes + extracted the mod-dependent Metal FARP into the new [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) repo (killing its every-mission-start WARN). Scenes are load-position-independent; scene asset validation moved to a design-time busted hard-gate (datamine ∪ `modTypes`); runtime scene audit removed; `requiresCtld` version check. ADRs [0006](../dev/adr/0006-pluggable-scenes.md)/[0007](../dev/adr/0007-design-time-asset-validation.md). CTLD PR #26; plugins repo bootstrapped (PR #1/#2). |
| `ASSET-VALIDATION-REVAMP` ✅ | Removed `CTLD_modValidator`'s runtime probe-spawn (no more spurious `S_EVENT_BIRTH`/destroy at mission start). Shared `CTLDTypeCollector` (fixes the GROUND `unitType` gate gap); `modTypes` config setting; optional dev-time asset-check companion (`dist/CTLD_asset_check.lua`, no-spawn lookup). ADR [0007](../dev/adr/0007-design-time-asset-validation.md). CTLD PR #27; plugins gate fix PR #3. |
| `CLEANUP-LEGACY-DCS-TESTS` ✅ | Purged 194 dead FullGas relics from `tests/dcs/noPlayer/` (dangling `dofile`, absent `ctld_test`, hardcoded paths). FullGas confirmed. 45 live dcs-bridge scenarios unaffected. PR #33. |
| `USERCONFIG-LOADING` ✅ | `CTLD_userConfig.lua` removed from build merge; new `CTLD_bootstrap.lua` keeps auto-start in deliverable; userConfig delivered in `dist/` as standalone MM template. PR #32. |

## Dropped lots

| Lot | Status | Reason |
|-----|--------|--------|
| `STYLUA-ADOPTION` | 🚫 wontfix | Adoption would reformat ~500 files for marginal benefit (code already consistent + luacheck-clean), and requires first untangling pre-existing CRLF blobs against a global `core.autocrlf=true`. Not worth it; `stylua.toml` removed. luacheck stays the sole Lua gate. |

## Archived lots

Completed lots are compacted under `archive/<LOT-ID>.md`.

| Lot | Description |
|-----|-------------|
| _(none yet)_ | |
