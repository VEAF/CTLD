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
| `CI-REVAMP` | ⬜ ready | Cover `develop`, factor the merge, coverage ratchet, stylua, gitleaks/dependabot/CODEOWNERS, PR/issue templates (PRD + 7 tickets) | `feature/ci-revamp` (tbd) |

### Planned lots

| Lot | Description |
|-----|-------------|
| `CONTEXT-ADR` | Retroactive ADRs in `dev/adr/` (OOP split, MIST removal, Legacy API, scene engine, repack→pack) + refine `CONTEXT.md` |
| `RELEASE` | Interactive `release` skill + `release.yml` (tag `published-v*`), release-notes workflow |
| `DOC-MKDOCS` | mkdocs-material infra, EN default + FR (i18n), `mike`, Pages deploy |
| `DOC-TECH` | Technical doc refonte: consolidate `docs/dev-guide`+`api-reference` and `migration/specs/`, fill gaps → `docs/developer/` |
| `DOC-USER-ROLES` | Split the monolithic user guide by role → `docs/pilot/`, `docs/mission-maker/` |
| `DCS-BRIDGE-MCP` | Wire VEAF-dcs-bridge (`.mcp.json`, `dcs-client mcp`), integration-testing skill, retire Witchcraft |
| `INTEGRATION-TEST-TAGS` | `-- @tier: auto\|auto-check\|ia` header convention, pre-tag the ~267 scenarios |
| `INTEGRATION-TEST-RUNNER` | Python runner over dcs-serve REST (`/api/exec`), tier filtering, JUnit report, "run without AI" |
| `DCS-DATAMINE-VENDOR` | Vendor DCS type/unit data from Quaggles/dcs-lua-datamine for `CTLD_modValidator` |
| `CLAUDE-AUTOMATIONS` | Hooks (block `migration/source/` + `CTLD_Next.lua`, luacheck on edit), subagents (lua51-compliance, legacy-parity) |

### Delivered (socle, this program)

| Lot | Description |
|-----|-------------|
| `REPO-BOOTSTRAP` | New VEAF repo, clean history, Git Flow `develop`/`master` |
| `PROCESS-SCAFFOLD` | Lean `CLAUDE.md`, `.backlog/`, `CONTEXT.md`, `dev/agents/`, `dcs-runtime-debug` skill, history cleanup |

## Archived lots

Completed lots are compacted under `archive/<LOT-ID>.md`.

| Lot | Description |
|-----|-------------|
| _(none yet)_ | |
