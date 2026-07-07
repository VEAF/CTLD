# 04 — Busted coverage ratchet

Status: ⬜ ready
Type: AFK

## What to build

Make the busted job measure coverage and enforce a `--cov-fail-under` floor stored in-repo. Seed the
floor ~2 points below the first measured value. The floor only ever rises (CLAUDE.md "Quality
ratchet"). Keep the existing `busted tests/ci/` run intact.

## Acceptance criteria

- [ ] The busted job produces a coverage measurement.
- [ ] CI fails when coverage drops below the recorded floor.
- [ ] The floor value is stored in-repo and documented as "only ever goes up".
- [ ] Initial floor seeded ~2 points below the first measured coverage.

## Blocked by

None - can start immediately.
