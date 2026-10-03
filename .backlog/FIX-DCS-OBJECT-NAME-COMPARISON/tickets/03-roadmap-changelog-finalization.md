# 03 — Roadmap notes, CHANGELOG, finalization

**Status:** ✅ done (PR #NN) · **Type:** AFK

## Parent

[PRD — FIX-DCS-OBJECT-NAME-COMPARISON](../PRD.md). Stories 15-16.

## What to build

- `dev/roadmap.md`: record the three neighbouring findings left out of the lot (troop-side zone queries
  ignoring `isAlive()`; the hard-coded English "Crate loaded (parachute-ready)" message; the identical
  bodies of the two crate loaded-state predicates), in the roadmap's own language and format.
- `CHANGELOG.md` `[Unreleased]`: entry for the lot, behaviour fixes separated.
- Rebuild `CTLD.lua`, confirm the i18n dictionaries are unchanged.
- Index line `merged (PR #NN)` in the delivering PR; PRD and ticket statuses ✅.
- PR to `develop` referencing `Fixes #236` and `Fixes #238`.

## Acceptance criteria

- [ ] Roadmap entries present for the three items.
- [ ] CHANGELOG entry present; dictionaries unchanged.
- [ ] Index `merged (PR #NN)`; statuses ✅.
- [ ] luacheck clean; `busted` green; CI green.

## Blocked by

- [01 — Crates on board](01-crates-on-board-by-name-and-total-capacity.md)
- [02 — Troop zone anchor death](02-troop-zone-anchor-death-by-name.md)
