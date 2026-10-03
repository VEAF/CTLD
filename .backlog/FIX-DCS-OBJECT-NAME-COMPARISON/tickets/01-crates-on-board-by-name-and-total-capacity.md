# 01 — Crates on board: one predicate, by name, one total capacity

**Status:** ✅ done (PR #NN) · **Type:** AFK

## Parent

[PRD — FIX-DCS-OBJECT-NAME-COMPARISON](../PRD.md). Source: GitHub issue #236. Stories 1-6, 11, 12, 14.

## What to build

Add to the crate manager a predicate "crate carried by the unit named N" (by name, an
unreadable name means not carried) and a list of the crates on board a named unit. Route the eight sites
through it: menu-load capacity, slung-crate lookup, hover-hook capacity, parachute selection, loaded-crate
weight, the Parachute Crates menu count, the Parachute Crates menu action collection, and the player cargo
status summary. Each site keeps its own extra filter.

Make `maxCratesOnboard` a total: the hover hook-up counts every crate on board, like the menu load.

Tests first, with the load-time transport and the check-time transport as distinct objects sharing a name:
parachute selection, slung-crate lookup (overspeed loses the crate), hover refused after a menu load at
capacity 1, and the crates-on-board list counting menu-loaded and slung crates together (the menu-load check
sits in an F10 callback closure and uses that list). Watch them fail, then fix.

## Acceptance criteria

- [ ] New busted cases fail before the change and pass after it (test committed first).
- [ ] No `loadedBy == transport` identity comparison remains in `src/`.
- [ ] Hover hook-up and menu load refuse at the same total capacity, in both orders.
- [ ] Existing crate, slingload and parachute specs pass unchanged.
- [ ] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
