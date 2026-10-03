# FIX-DCS-OBJECT-NAME-COMPARISON — compare DCS objects by name, and count crates on board one way

**Status:** ⬜ ready

Formalizes GitHub issues #236 and #238 (automated code review of `develop`), re-read against the current code:
both defects are still present. Lot C of the review follow-up, after `FIX-REVIEW-HYGIENE-A` and
`FIX-PARACHUTE-TROOPS-SPAWN-FAILURE`. Decisions come from a `grill-with-docs` session held 2026-10-03.

## Problem Statement

**Crates on board (#236).** Eight places answer "which crates are on board this transport?" and they disagree.
The repository rule (`CTLD_player.lua`: "Compare by unit name, not object identity (DCS userdata equality is
unreliable)") is followed by four of them. Four others compare the handle stored when the crate was loaded with
a transport handle re-resolved on every tick, by `==`. Where those two handles differ, three things break
silently:

- the F10 "Parachute Crates" entry is offered (its count is by name) but triggering it answers "No crates
  loaded." with the crates still on board (its selection is by identity);
- the overspeed penalty never applies: the slung crate is not found, so the pilot flies at any speed under
  sling, and the hover state is cleared anyway so nothing flags it;
- the carrying limit can be exceeded: the menu load counts every crate on board against `maxCratesOnboard`,
  but the hover hook-up counts only slung ones, so a UH-1H (limit 1) that loaded a crate through the menu can
  hook a second one in hover and carry twice its declared capacity.

The legacy script had a single list for both loading modes compared with a single capacity, so the hover
asymmetry is a regression, not a feature.

**Troop zone of a dead anchor (#238).** A troop zone anchored to a unit or a group is removed when the anchor
dies; the only removal path compares the DCS object stored at zone creation with the `event.initiator` supplied
by the event engine, by identity — the only place in `src/` doing so, while the sibling branch of the same
condition and every other death handler compare names. If DCS does not hand back the same object, the troop
zone of a sunk ship or a destroyed convoy stays registered for the rest of the mission and players keep
boarding troops above the water. The existing test passes the same table as anchor and as initiator, so the
equality is true by construction and the test cannot notice.

## Solution

One definition of "this crate is on board this transport", by unit name, used everywhere, and one capacity
rule: `maxCratesOnboard` caps the total number of crates on board, whatever the loading mode. The troop-zone
removal compares the anchor's name with the dead unit's name, like its neighbouring branch. Tests use distinct
objects carrying the same name so the property they claim is actually exercised.

## User Stories

1. As a pilot, I want the "Parachute Crates" action to drop the crates the menu told me I have, so that the
   menu and the action never contradict each other.
2. As a pilot, I want a crate slung too fast to be lost as the rules say, so that the overspeed limit means
   something.
3. As a pilot of a one-crate aircraft, I want not to be able to hook a second crate in hover after loading
   one through the menu, so that my aircraft never carries more than its declared capacity.
4. As a pilot, I want the same capacity check whether I load by menu or by hover, so that the limit does not
   depend on how I loaded.
5. As a pilot, I want a crate hooked in hover to count against the same limit as a menu-loaded one, so that
   both orders (menu then hover, hover then menu) are refused alike once the aircraft is full.
6. As a pilot, I want the cargo status summary, the weight of my load and the Parachute Crates entry to agree
   on which crates are on board, so that I can trust what I read.
7. As a pilot, I want the troop zone of a ship or convoy that was destroyed to disappear, so that I am never
   offered a boarding zone over the water.
8. As a pilot, I want a troop zone that still has a living anchor to stay, so that the fix removes nothing it
   should not.
9. As a mission maker, I want the Moving-Zone-anchored `TRZ_` zones to keep being removed by anchor name, so
   that this path is unchanged.
10. As a mission maker, I want a logistic zone whose unit died to keep being removed as before, so that the
    zone side is not regressed.
11. As a CTLD developer, I want a single predicate for "crate carried by this unit name", so that a future
    change cannot reintroduce an identity comparison in one of eight copies.
12. As a CTLD developer, I want tests where the transport used at load time and the one used at check time are
    distinct objects with the same name, so that the tests fail if an identity comparison comes back.
13. As a CTLD developer, I want the same distinct-object setup for the anchor-death test, so that it no longer
    passes by construction.
14. As a CTLD developer, I want a released or dead DCS object never to raise when its name is read, so that a
    stale crate or zone cannot crash a tick.
15. As a maintainer, I want the three neighbouring findings (troop-side `isAlive()` filtering, a hard-coded
    English message, duplicate crate-state predicates) recorded in the roadmap, so that they are not lost.
16. As a maintainer, I want a CHANGELOG entry separating the behaviour fixes, so that release notes are
    accurate.

## Implementation Decisions

- **Predicate (crate manager):** a method answering "is this crate carried by the unit named N" compares the
  stored carrier's name with N (the carrier must still exist; an unreadable name is "not carried"). A
  companion lists the crates on board a named unit. Both live in the crate manager, the single owner of the
  crate registry.
- **Routing:** the four identity comparisons (menu-load capacity, slung-crate lookup, hover-hook capacity,
  parachute selection) and the name-based copies (loaded weight, Parachute Crates menu count, Parachute
  Crates menu action collection, player cargo status summary) all go through the predicate. Each site keeps
  its own extra filter (slung or not, CTLD-managed or not), only the "carried by" part is shared.
- **Capacity:** `maxCratesOnboard` is a **total** across loading modes, as in the legacy script. The hover
  hook-up counts every crate on board, like the menu load. No new setting, no schema change, no
  `configVersion` change.
- **Zones:** the unit/group anchor branch of the zone manager's death handler compares the anchor's name
  (read safely) with the dead unit's name. The second branch (stored anchor name) is untouched.
- **No identity assumption, no live DCS test:** comparing names is correct whether or not DCS guarantees
  object identity, so the open question of #238 and #236 does not need measuring.
- **Legacy parity:** the single-capacity rule restores legacy behaviour; the by-name comparison has no legacy
  counterpart to preserve (the legacy tracked crates by name already).
- **Out of scope, recorded in `dev/roadmap.md`:** troop-side zone queries ignoring `isAlive()`; the
  hard-coded English "Crate loaded (parachute-ready)" player message; the identical bodies of the two crate
  loaded-state predicates.
- No i18n key is added or changed; no catalogue change.

## Testing Decisions

- A good test observes external behaviour: whether a crate is found, counted, dropped or refused; whether a
  zone remains registered. It builds the transport used at load time and the one used at check time as
  **distinct objects sharing a name**, which is the situation the defect is about.
- Seams: the existing crate manager specs (`crate_manager_spec`, `crate_lifecycle_spec`) and the
  parachute/slingload functional spec for the crate side; the existing troop-zone scripted API spec for the
  zone side (its anchor-death case is rewritten to use a distinct initiator).
- New cases, written first and seen failing: parachute selection finds a crate loaded on a distinct same-name
  transport; the slung-crate lookup finds it (overspeed loses the crate); the menu-load capacity and the hover
  hook-up capacity both count a crate loaded by the other mode (hover refused after a menu load at capacity 1,
  menu refused after a hover hook-up); anchor death removes the troop zone when the initiator is a distinct
  object with the anchor's name, and does not remove it for a different name.
- Existing tests pass unchanged apart from the anchor-death case's initiator.
- No live-DCS test.

## Out of Scope

- The three roadmap items above, and the other findings of the review (#234).
- Introducing separate cabin / sling limits or a new setting.
- Any change to unload, pack or unpack behaviour.

## Further Notes

Source issues: #236 (found at `8d37a58`) and #238 (found at `7535ba0`). The PR references them with
`Fixes #236` and `Fixes #238`.
