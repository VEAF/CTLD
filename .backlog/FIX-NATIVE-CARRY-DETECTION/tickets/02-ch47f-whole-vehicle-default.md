# 02 — CH-47F is whole-vehicle capable by default

**Status:** ✅ done (busted only; no live CH-47F available) · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). Stories 7, 15.

## What to build

The default aircraft capability entry for the `CH-47Fbl1` gains whole-vehicle carry. Its loadable
vehicle types, maximum vehicle weight and maximum vehicle count are already present in the default
configuration and are left as they are. A CH-47F pilot then gets the *Vehicle Commands* F10 menu
with the virtual-carry load, unload and parachute entries.

The generated defaults copy shipped inside the deliverable is refreshed by the normal build, not
edited by hand.

## Acceptance criteria

- [ ] The default configuration marks the `CH-47Fbl1` as whole-vehicle capable, with its existing
      lists and limits unchanged.
- [ ] A CH-47F player gets the Vehicle Commands menu (asserted through the menu-gating behavior).
- [ ] No other aircraft entry changes.
- [ ] Busted spec on the aircraft capabilities covers the CH-47F entry.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Changed` entry.

## Blocked by

None - can start immediately.
