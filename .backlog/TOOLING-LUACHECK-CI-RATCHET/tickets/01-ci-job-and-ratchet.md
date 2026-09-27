# 01 — New `luacheck` CI job with an inverted warning-count ratchet

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

Add a new job `luacheck` to `.github/workflows/ci.yml`, structurally parallel to the existing
`lua-lint`/`busted` jobs:

- `runs-on: ubuntu-latest`.
- Install `luacheck` via `luarocks` (same install shape the `busted` job already uses for its own
  LuaRocks packages: `lua5.1`, `liblua5.1-dev`, `luarocks`, then `luarocks install luacheck`).
- Run `luacheck --config .luacheckrc src/`, capture output.
- Parse the summary line ("Total: N warnings / M errors in K files") for the warning count `N` and
  error count `M` — same `awk`-based parsing style the `busted` job already uses for `luacov`'s
  "Total" line.
- Fail unconditionally if `M > 0` (0 errors, non-negotiable).
- Fail if `N` exceeds `LUACHECK_WARNING_CEILING` (env var on the job, set to `89` — today's real,
  freshly-reverified count).
- Pass and print the current count otherwise.

## Watch out

- This is a **new, separately-named job** — do not fold this into `lua-lint` (syntax-only today)
  or `busted` (coverage ratchet, a different concern). Matches this workflow's one-job-one-concern
  convention.
- No `skip-luacheck` label escape hatch — deliberately not built (see PRD).
- `LUACHECK_WARNING_CEILING`'s comment must state the ratchet rule explicitly ("only ever decrease,
  never increase"), mirroring `COVERAGE_FLOOR`'s own comment style.
- Don't touch `.luacheckrc` in this ticket — nothing here requires a config change.
- Verify the parsing against the real current output (`89 warnings / 0 errors in 33 files`) before
  considering this done — don't guess the exact summary-line format.

## Acceptance

- A new `luacheck` job appears in the PR checks list.
- It passes today (89 warnings, 0 errors ≤ ceiling of 89).
- A deliberately introduced extra warning (test locally, then revert) would fail the job; a
  deliberately introduced error would fail the job regardless of the ceiling.

## Tests

None — a CI workflow has no local unit-test harness in this repo (checked: no test file exercises
`.github/workflows/`). Verified by observing the real job run on this ticket's own PR.
