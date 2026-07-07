# Lot CI-REVAMP — professional-grade CI for CTLD_Next

Status: ✅ done
Branch: feature/ci-revamp → PR #1 → develop (merged)
Program: re-tooling CTLD_Next on the VMCT model (see `.backlog/README.md`)

## Problem Statement

The inherited CI (`.github/workflows/ci.yml`, from FullGas1) works for the happy path but has
concrete gaps that hurt day-to-day development on the new VEAF repo:

- The working branch **`develop` is not covered** — triggers only fire on `master` and
  `feature_*`, so nothing runs on `develop` pushes or on PRs targeting `develop`. The main branch
  gets zero CI feedback.
- The Lua **merge logic is duplicated three times** (the `build` job re-implements it inline in
  PowerShell, the `release` job does it a third time, and `tools/build/merge_CTLD.ps1` is the real
  script). Three copies drift independently.
- The **`docs` job is broken**: it runs `mkdocs gh-deploy` but there is no `mkdocs.yml` in the
  repo, so it fails whenever it triggers.
- No professional guard-rails: no coverage ratchet, no formatting check, no secret scanning, no
  dependency updates, no ownership or contribution templates.

## Solution

A revamped CI that gives fast, trustworthy feedback on every change to `develop` and every PR,
builds the deliverable from the single source of truth, enforces a rising quality bar, and adds
the standard hygiene a VEAF open-source repo expects — without regressing the working
`lua-lint` and `busted` jobs.

## User Stories

1. As a CTLD_Next maintainer, I want CI to run on every push to `develop` and every PR targeting
   `develop`, so that the main working branch always has feedback.
2. As a maintainer, I want the CI build to call `tools/build/merge_CTLD.ps1` rather than a private
   copy of the merge logic, so that there is a single source of truth for how `CTLD_Next.lua` is
   produced.
3. As a maintainer, I want the busted job to enforce a coverage floor that only ever rises, so
   that test coverage cannot silently regress.
4. As a contributor, I want a formatting check (stylua) in CI, so that Lua style stays consistent
   without manual policing.
5. As a maintainer, I want secret scanning (gitleaks) on pushes and PRs, so that credentials are
   never committed to a public VEAF repo.
6. As a maintainer, I want automated dependency-update PRs (dependabot), so that GitHub Actions
   and tooling stay current without manual chores.
7. As a maintainer, I want `CODEOWNERS` and issue/PR templates, so that reviews are routed and
   contributions arrive in a consistent shape.
8. As a maintainer, I want the broken `docs` job removed (its work handed off to the DOC-MKDOCS
   lot), so that CI is green and honest instead of failing on a missing `mkdocs.yml`.
9. As a maintainer, I want the release concern kept out of this lot (handed to the RELEASE lot),
   so that CI-REVAMP stays focused on validation, not publication.
10. As a contributor on Windows, I want the Lua quality gate enforced in CI, so that I can rely on
    the CI check when luacheck/stylua are not installed locally.

## Implementation Decisions

- **Triggers**: cover `develop` and `master` on push, and `pull_request` targeting `develop` (and
  `master`). Keep `workflow_dispatch`. Tag-based release triggers move to the RELEASE lot.
- **Single build source**: the build job invokes `tools/build/merge_CTLD.ps1` (on a Windows
  runner) and uploads `CTLD_Next.lua` as an artifact. The inline PowerShell re-implementation is
  deleted. The release-time build is out of scope (RELEASE lot).
- **Keep** the `lua-lint` job (`luac5.1 -p` over `src/**/*.lua`) and the `busted` job
  (`busted tests/ci/`) — they are correct and aligned with the Lua 5.1 constraint.
- **Coverage ratchet**: the busted job measures coverage and enforces `--cov-fail-under` at a
  floor tracked in-repo; the floor only ever increases (see CLAUDE.md "Quality ratchet"). The
  initial floor is set ~2 points below the first measured value.
- **Formatting**: add a `stylua --check` job. Introduce a `stylua.toml` consistent with the
  existing `.luacheckrc`/`.editorconfig` intent (indentation, line width). This makes stylua the
  project formatter (a professional standard the inherited setup lacked).
- **Secret scanning**: add a `gitleaks` job on push/PR over full history, with a `.gitleaks.toml`
  if tuning is needed.
- **Repo hygiene**: add `.github/dependabot.yml` (github-actions ecosystem, weekly),
  `.github/CODEOWNERS`, `.github/ISSUE_TEMPLATE/{bug_report,feature_request}.md` (or `.yml`), and
  `.github/pull_request_template.md`.
- **Broken docs job**: remove the `docs` job from `ci.yml`. Publishing docs is DOC-MKDOCS's
  responsibility; note the handoff in the PRD/CHANGELOG.
- **No new Lua** is expected; if any Lua is touched it must remain Lua 5.1 strict.

## Testing Decisions

- The unit of verification for a CI lot is the **workflow run itself**, not a busted spec: good =
  the revamped workflow runs green on a PR targeting `develop`, exercises every job, and each job
  does what it claims (build produces the artifact via `merge_CTLD.ps1`; ratchet fails on a
  deliberately-lowered coverage; stylua fails on a deliberately-misformatted file; gitleaks flags
  a planted fake secret in a scratch branch).
- Prior art: the existing `lua-lint` and `busted` jobs are the reference for job structure and for
  the Lua 5.1 toolchain setup (lua5.1 + luarocks + busted) already proven in `ci.yml`.
- The coverage-ratchet behaviour is validated by a one-off local `busted --coverage` run to seed
  the floor, then confirmed by CI rejecting a floor breach.

## Out of Scope

- `mkdocs.yml` and docs publication → **DOC-MKDOCS** lot.
- Release automation (tag `published-v*`, `release.yml`, release notes) → **RELEASE** lot.
- Any change to Lua source, tests, or the merge script's own logic.
- Migrating integration tests to dcs-bridge → **DCS-BRIDGE-*** lots.

## Further Notes

This is the pilot lot for dogfooding the `.backlog/` → PRD → tickets pipeline on the new VEAF repo.
It is intentionally self-contained (no DCS, no external infra) so the process and the green-CI
baseline can be validated quickly before the heavier dcs-bridge lots.
