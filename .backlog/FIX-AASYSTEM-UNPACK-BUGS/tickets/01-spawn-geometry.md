Status: ⬜ ready

# 01 — Fix AA system spawn geometry (arc-step formula)

## What to build

Correct the arc-step formula in `CTLDCrateAssemblyManager:_buildSpawnArrays` so that
multiple units belonging to the same template part are distributed **within their reserved
arc segment**, not across the full circle.

Current formula (buggy): `step = arcRad / partAmount`
Correct formula: `step = (arcRad / partCount) / partAmount`

This ensures that when a part has `amount > 1` (e.g. S-300 TEL D with `amount = 2`),
its units stay within the `[arcBase, arcBase + arcSegment)` arc and do not overlap with
units of other parts. The fix is generic and covers all AA system templates.

Deliver with a busted L1 unit test asserting that all spawned positions returned by
`_buildSpawnArrays` are pairwise-distinct (within a 1 m tolerance) for a template
containing at least one multi-unit part.

## Acceptance criteria

- [ ] `_buildSpawnArrays` uses `(arcRad / partCount) / partAmount` as the intra-segment step
- [ ] No two positions in the returned array share the same `{x, z}` within 1 m for any
      standard template (HAWK, Patriot, NASAMS, BUK, KUB, S-300) with default `aaLaunchers`
- [ ] New busted L1 test covers a template with a NoCrate part with `amount = 2` alongside
      single-unit parts and asserts pairwise-distinct positions
- [ ] All existing `tests/ci/` pass (busted)
- [ ] luacheck clean on changed files
- [ ] `CTLD.lua` rebuilt via `merge_CTLD.ps1`

## Blocked by

None — can start immediately.
