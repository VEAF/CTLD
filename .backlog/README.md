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
| `FIX-LIVE-DCS-FAILURES` | ✅ pending merge | Triage the 10 (of 18) failures from the first live run (2026-07-10, `test-results-run2.xml`) not already fixed by `POST-FULLGAS-FIXES` — all 10 turned out to be cross-scenario state contamination, cleared by a mission reload (48/48 green, no src/test change). | fix/live-dcs-failures-triage |

### Planned lots

| Lot | Description |
|-----|-------------|
| `CLEANUP-LEGACY-DCS-TESTS` | Purge the ~194 dead FullGas relics under `tests/dcs/noPlayer/` (dangling `dofile` of `DCS-CTLD_FG/recette/setup.lua`, absent `ctld_test` framework, hardcoded `Users/Moi` paths — never re-tooled at the VEAF bootstrap). **Talk to FullGas before purging** (confirm none are worth re-tooling). Separate PR from the DCS-bridge triptych. |

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

## Dropped lots

| Lot | Status | Reason |
|-----|--------|--------|
| `STYLUA-ADOPTION` | 🚫 wontfix | Adoption would reformat ~500 files for marginal benefit (code already consistent + luacheck-clean), and requires first untangling pre-existing CRLF blobs against a global `core.autocrlf=true`. Not worth it; `stylua.toml` removed. luacheck stays the sole Lua gate. |

## Archived lots

Completed lots are compacted under `archive/<LOT-ID>.md`.

| Lot | Description |
|-----|-------------|
| _(none yet)_ | |
