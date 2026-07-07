# Backlog — CTLD_Next

Local markdown backlog. One lot = one directory `<LOT-ID>/` (`PRD.md` + `tickets/`). This file is
the hand-maintained index. See `dev/agents/issue-tracker.md` for conventions and
`dev/agents/triage-labels.md` for the `Status:` vocabulary.

## Program — re-tooling CTLD_Next on the VMCT model

The codebase is mature (v2.0.0). This program installs a professional process/tooling layer around
it and migrates DCS integration testing from Witchcraft to VEAF-dcs-bridge. PRDs and tickets are
authored **per lot, when the lot is started** (not in batch).

### Active lots

| Lot | Status | Description | Branch |
|-----|--------|-------------|--------|
| `RELEASE` | 🔄 in-progress | `release` skill (community notes + version bump + release PR) + `release.yml` (tag `published-v*`) | `feature/release` |

### Planned lots

| Lot | Description |
|-----|-------------|
| `DOC-MKDOCS` | mkdocs-material infra, EN default + FR (i18n), `mike`, Pages deploy |
| `DOC-TECH` | Technical doc refonte: consolidate `docs/dev-guide`+`api-reference` and `migration/specs/`, fill gaps → `docs/developer/`. MUST include a "Development workflow" page documenting the backlog process and the Matt Pocock skills used (`grill-with-docs`, `to-prd`, `to-issues`). |
| `DOC-USER-ROLES` | Split the monolithic user guide by role → `docs/pilot/`, `docs/mission-maker/` |
| `DCS-BRIDGE-MCP` | Wire VEAF-dcs-bridge (`.mcp.json`, `dcs-client mcp`), integration-testing skill, retire Witchcraft |
| `INTEGRATION-TEST-TAGS` | `-- @tier: auto\|auto-check\|ia` header convention, pre-tag the ~267 scenarios |
| `INTEGRATION-TEST-RUNNER` | Python runner over dcs-serve REST (`/api/exec`), tier filtering, JUnit report, "run without AI" |

### Delivered (socle, this program)

| Lot | Description |
|-----|-------------|
| `REPO-BOOTSTRAP` | New VEAF repo, clean history, Git Flow `develop`/`master` |
| `PROCESS-SCAFFOLD` | Lean `CLAUDE.md`, `.backlog/`, `CONTEXT.md`, `dev/agents/`, `dcs-runtime-debug` skill, history cleanup |
| `CI-REVAMP` ✅ | CI on `develop`, single build source, coverage ratchet (59%/61.56%), gitleaks, hygiene (PR #1). |
| `CONTEXT-ADR` ✅ | Retroactive ADRs 0001–0005 in `dev/adr/` (PR #4). |
| `CLAUDE-AUTOMATIONS` ✅ | Project hooks (block protected paths, luacheck-on-edit) + subagents lua51/parity (PR #5). |
| `DCS-DATAMINE-VENDOR` ✅ | Vendored DCS type set (not shipped) + offline config type linter (PR #6). |

## Dropped lots

| Lot | Status | Reason |
|-----|--------|--------|
| `STYLUA-ADOPTION` | 🚫 wontfix | Adoption would reformat ~500 files for marginal benefit (code already consistent + luacheck-clean), and requires first untangling pre-existing CRLF blobs against a global `core.autocrlf=true`. Not worth it; `stylua.toml` removed. luacheck stays the sole Lua gate. |

## Archived lots

Completed lots are compacted under `archive/<LOT-ID>.md`.

| Lot | Description |
|-----|-------------|
| _(none yet)_ | |
