Status: ⬜ ready

# PRD — FIX-AASYSTEM-UNPACK-BUGS

## Problem Statement

When a pilot deploys a long-range SAM system (e.g. S-300) by dropping the required crates and
selecting an unpack option from the F10 menu, two bugs occur:

1. **Stale unpack menu** — after a successful assembly, the F10 "Unpack Crate" submenu still
   shows all three part options (launcher, track radar, search radar…). The menu never refreshes,
   so the pilot believes the assembly failed and may attempt to click again, receiving a "Not
   enough crates nearby" error.

2. **Overlapping unit spawn** — one of the S-300 parts (TEL D, a NoCrate part with `amount = 2`)
   is spawned at the same position as another part (Big Bird SR) because the arc-distribution
   formula spreads multi-unit parts across the full circle instead of their reserved arc segment.
   The overlapping units are physically superimposed in DCS.

## Solution

Fix both bugs in the AA system unpack path:

1. **Menu refresh** — after `_assemble()` destroys each consumed crate, publish `OnCrateCleared`
   for each one so that `_refreshNearbyPlayers` fires and rebuilds the F10 unpack submenu for
   all pilots within range.

2. **Spawn positions** — correct the arc-step formula so that multiple units of the same part
   are distributed within their reserved arc segment, not across the full circle.

## User Stories

1. As a pilot, I want the F10 "Unpack Crate" submenu to disappear or become empty immediately
   after a successful AA system assembly, so that I know the assembly succeeded.
2. As a pilot, I want the F10 unpack menu to refresh for all nearby pilots at the same time, so
   that no teammate accidentally tries to unpack crates that have already been consumed.
3. As a pilot, I want all AA system units to be spawned at distinct positions after assembly,
   so that I can visually confirm every component of the system is correctly placed.
4. As a pilot, I want the spawned AA system units to be arranged in a predictable radial pattern
   around the assembly origin, so that the system is easy to find and operate.
5. As a mission maker, I want the AA system unpack to behave consistently regardless of which
   part option the pilot clicks in the menu, so that the assembly is deterministic.

## Implementation Decisions

- **Menu refresh**: `_assemble()` must publish `OnCrateCleared` for every CTLDCrate it destroys.
  The existing contract — `OnCrateCleared` → `_refreshNearbyPlayers()` — is already wired in
  `CTLDCrateManager`; no new event or listener is needed. The payload must carry `position` so
  the proximity filter works correctly.

- **Spawn geometry fix**: In `_buildSpawnArrays`, the step used to distribute `partAmount` units
  within their arc segment must be `(arcRad / partCount) / partAmount` (the segment width divided
  by the unit count), not `arcRad / partAmount` (which distributes across the full circle).
  This keeps all units of a part within the `[arcBase, arcBase + arcSegment)` arc.
  The behaviour is not identical to the legacy monolith (which positioned units around each
  part's crate centroid), but it is more predictable and this deviation is accepted.

- **No API surface change**: both fixes are internal to `CTLDCrateAssemblyManager`; no
  inter-module contract changes.

## Testing Decisions

A good test verifies external, observable behaviour — not internal call order:
- For the menu bug: assert that after assembly, no nearby crate of the consumed types remains
  registered in `CTLDCrateManager` (the menu is driven by registered crates, so an empty
  registry ↔ empty menu).
- For the spawn geometry: assert that all spawned positions are distinct (no two units at the
  same `{x, z}` within a tolerance).

**L1/L2 (busted, no DCS):**
- Prior art: `tests/ci/unit/CTLD_aasystem_spec.lua` — extend with a test that calls `_assemble()`
  on a mocked template and asserts `OnCrateCleared` is published once per consumed crate.
- Extend `_buildSpawnArrays` unit tests to assert that positions are pairwise-distinct for a
  template with a multi-unit NoCrate part (e.g. a 2-launcher part alongside other parts).

**L3 (live DCS, no player):** existing `auto-check` AA scenarios cover end-to-end spawn; verify
they still pass after the fix. No new scenario required unless the busted gate is insufficient.

## Out of Scope

- AA system `_rearm()` and `_repair()` paths — they also call `crate:destroy()` directly without
  publishing `OnCrateCleared`. These are separate, lower-priority issues and are not addressed
  here.
- Replicating the legacy spawn centroid behaviour (each part positioned around its own crate
  group centroid).
- Menu refresh behaviour for non-AA unpack paths.

## Further Notes

Reported by a field tester on the S-300 ("SAM long range") system. Both bugs exist in the
same function (`_assemble`) and fix cleanly without touching any other manager boundary.
