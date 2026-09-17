# 03 — `_checkNativeLoading` does not use `CTLDPlayerTracker`

**Status:** ✅ done

`CTLDVehicleSpawner:_checkNativeLoading` ([CTLD_vehicle.lua:671](../../src/CTLD_vehicle.lua#L671))
opens its transport loop with:

```lua
-- Iterate transports currently known as player units (via CTLDPlayerTracker)
-- and check each capable-transport unit that we can find by name
-- Simple approach: scan all groups of both coalitions for matching type
```

The first line names a class that has never been instantiated (#150). The third admits the
workaround, and the code below sweeps every group of both coalitions. Anyone reading this believes
a player index exists and is consulted here; neither is true.

## What changes

`src/CTLD_vehicle.lua`, comment only: say what the loop does — scan both coalitions' airplane
groups for capable transports — and drop the `CTLDPlayerTracker` reference. No behaviour change,
no code change.

## Watch out

- Comment only. Rewriting this loop onto a player index is #150's subject, not this lot's — and
  the index it would need does not exist yet.
- Keep the note that the early `return` above bounds the cost: it is the reason the sweep is
  acceptable, and removing it invites someone to "fix" a non-problem.
- PR carries `skip-changelog` only if it ships alone; here it rides with tickets 01 and 02, which
  have their own entry.

## Acceptance

- [x] The comment describes the sweep the code performs, with no mention of `CTLDPlayerTracker`.
- [x] `git diff` on this ticket touches comment lines only.
