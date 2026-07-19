# 01 — CI CHANGELOG guard job

Status: ⬜ ready
Type: AFK
Repo: CTLD
GitHub: —

## What to build

Add a new job `changelog-guard` to `.github/workflows/ci.yml` that fails a pull request touching
shipped source without a CHANGELOG entry.

- **Job runs on pull requests only**: guard with `if: github.event_name == 'pull_request'`
  (the workflow also fires on `push` to `develop`/`master` and `workflow_dispatch` — those must not
  trip the guard, so the `chore(backlog): close` commits pushed straight to `develop` stay clean).
- **Checkout with `fetch-depth: 0`** so the base commit is available.
- **Compute the diff** with
  `git diff --name-only ${{ github.event.pull_request.base.sha }}...HEAD`.
- **Fail condition**: the diff contains at least one `src/**` path **and** does not contain
  `CHANGELOG.md`.
- **Escape hatch**: skip the check when the PR carries the `skip-changelog` label — read from
  `${{ contains(github.event.pull_request.labels.*.name, 'skip-changelog') }}` (job-level `if`, or an
  early step that neutralises the check).
- **Failure output must be actionable**: name `CHANGELOG.md`, state that a `src/`-touching PR needs an
  `[Unreleased]` entry, and mention the `skip-changelog` label as the deliberate waiver.

Trigger is intentionally limited to `src/**` (see PRD *Implementation Decisions*): a change to
shipped product code always warrants a CHANGELOG line. Test-/tooling-/docs-only PRs stay under
discipline + review.

No `src/` change, no rebuild. This lot's own PR touches only `.github/`, `CLAUDE.md`, `dev/` — so it
does not trip its own guard, which is correct.

## Acceptance criteria

- [ ] New `changelog-guard` job in `ci.yml`, conditioned to `pull_request` events only.
- [ ] Job **fails** when the diff touches `src/**` but not `CHANGELOG.md`.
- [ ] Job **passes** when `CHANGELOG.md` is also edited.
- [ ] Job **passes** (check skipped) when the PR has the `skip-changelog` label.
- [ ] Failure message names `CHANGELOG.md` and the `skip-changelog` escape hatch.
- [ ] `push` to `develop`/`master` and `workflow_dispatch` runs do not execute/fail the guard.
- [ ] Behaviourally validated: a `src/`-only probe change with no CHANGELOG edit fails; adding a
      CHANGELOG line (or the label) turns it green.

## Blocked by

None. Independent of ticket 02.
