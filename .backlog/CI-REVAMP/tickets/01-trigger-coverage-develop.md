# 01 — Cover `develop` on push and PR

Status: ⬜ ready
Type: AFK

## What to build

Extend the CI workflow triggers so every push to `develop` and every `pull_request` targeting
`develop` runs the pipeline. Keep `master` coverage and `workflow_dispatch`. The main working
branch must get full CI feedback.

## Acceptance criteria

- [ ] Push to `develop` triggers all validation jobs.
- [ ] A PR targeting `develop` triggers all validation jobs.
- [ ] `master` push/PR coverage and `workflow_dispatch` still work.
- [ ] Stale `feature_*`-only assumptions removed from triggers.

## Blocked by

None - can start immediately.
