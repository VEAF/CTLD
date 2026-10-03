# 01 — One placement rule shared by Request Equipment and Drop Crate(s)

**Status:** ✅ done (PR #NN) · **Type:** AFK

## Parent

[PRD — FIX-CRATE-DROP-PLACEMENT](../PRD.md). Stories 1-3, 7-14.

## What to build

Make the placement of a wave of crates around an aircraft a routine shared by the wave spawn (requested and packed
crates) and by Drop Crate(s): the row layout with the other-side anti-collision for a type that declares a spawn
plan, and the radial rule with its anti-collision for a type that does not. Drop Crate(s) asks the crate manager for
the positions of the crates it drops, one size per crate, and keeps using the returned clock direction in its
message. Requested and packed waves behave exactly as before.

Tests first, in a new functional spec driving the Drop Crate(s) callback with and without a declared plan: crates in
a row at the plan distance (not on the radial rule); the row moves to the other side when the first is inside
another aircraft's volume; a type without a plan keeps the radial distance and passes the other aircraft's volumes
to the radial routine; each crate uses its own size. Watch them fail, then refactor and fix.

## Acceptance criteria

- [ ] New cases fail before the change and pass after it (test committed first).
- [ ] The existing crate spawn specs for requested and packed crates pass unchanged.
- [ ] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
