# 02 — Close Dependabot PR #193/#194 as superseded

**Status:** ⬜ ready

**Blocked by:** ticket 01 (must be merged first — closing the Dependabot PRs before the real fix
lands would leave the `vitest` bump unresolved with nothing proposing it).

## What to build

Once ticket 01's PR is merged, comment on and close
[PR #193](https://github.com/VEAF/CTLD/pull/193) and
[PR #194](https://github.com/VEAF/CTLD/pull/194), each pointing to the merged PR that supersedes
them (same `vitest` `^5.0.1` bump, plus the `tsconfig.app.json` fix that made it safe to merge).

## Watch out

- Don't merge either Dependabot PR — its diff is superseded, not reused as-is (it lacks the
  `tsconfig.app.json` fix and would still fail CI on its own).
- Dependabot may auto-close one of the two on its own once it detects the dependency is already
  at the target version on `develop` — check both PRs' state before closing to avoid a redundant
  "already closed" action, not to skip the check entirely.

## Acceptance

- PR #193 and PR #194 are both closed (whether by this action or confirmed already auto-closed by
  Dependabot), each with a comment or closing reference pointing to the PR that superseded them.

## Tests

None — this is a repository-hygiene action (PR state), not a code change.
