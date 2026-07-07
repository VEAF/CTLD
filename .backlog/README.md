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
| `DOC-USER-ROLES` | 🚧 in progress | Split the monolithic user guide by role → bilingual `docs/pilot/` + `docs/mission-maker/`. | `feature/doc-user-roles` |

### Planned lots

| Lot | Description |
|-----|-------------|
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
| `RELEASE` ✅ | `release` skill + `release.yml` (tag `published-v*`); release job moved out of ci.yml (PR #7). |
| `DOC-MKDOCS` ✅ | mkdocs-material infra (i18n EN+FR, mike) + `docs.yml` → gh-pages live at veaf.github.io/CTLD (PR #8). |
| `DOC-TECH` ✅ | Bilingual `docs/developer/` consolidation (20 EN + 20 FR pages) + workflow page; old sources + `migration/specs/` removed (PR #11). |

## Dropped lots

| Lot | Status | Reason |
|-----|--------|--------|
| `STYLUA-ADOPTION` | 🚫 wontfix | Adoption would reformat ~500 files for marginal benefit (code already consistent + luacheck-clean), and requires first untangling pre-existing CRLF blobs against a global `core.autocrlf=true`. Not worth it; `stylua.toml` removed. luacheck stays the sole Lua gate. |

## Archived lots

Completed lots are compacted under `archive/<LOT-ID>.md`.

| Lot | Description |
|-----|-------------|
| _(none yet)_ | |
