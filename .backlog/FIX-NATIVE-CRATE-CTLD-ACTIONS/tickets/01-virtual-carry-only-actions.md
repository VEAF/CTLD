# 01 — Unload, parachute and weight apply to virtual-carry crates only

**Status:** ✅ done (PR #247) · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CRATE-CTLD-ACTIONS](../PRD.md). Stories 1-17.

## What to build

Make `isLoadedByCTLD()` mean "loaded and in virtual carry (not native)", make `load()` clear the native flag,
and let the four existing call sites (loaded-crate weight, parachute selection, "Parachute Crates" menu count,
"Drop Crate(s)" collection) follow. Remove the parachute branch that destroyed a native crate's DCS object.
Correct the comments (the native flag, the weight function, the Drop collection, the parachute menu) and the
developer crate documentation (EN + FR).

Tests first, in a new functional spec on the crate manager: native crate not collected by Drop and not
parachuted (stays loaded, DCS object not destroyed); Parachute Crates entry disabled with only native crates on
board; loaded-crate weight excludes native and includes virtual, alone and mixed; a crate released natively then
loaded through the menu counts as virtual; the predicate's truth table. Watch them fail, then fix.

## Acceptance criteria

- [ ] New cases fail before the change and pass after it (test committed first).
- [ ] Virtual-carry behaviour, vehicles, troops, slingload and native release detection unchanged: existing specs
      pass unchanged.
- [ ] No contradictory comment remains at the four call sites or on the native flag.
- [ ] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
