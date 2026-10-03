# FIX-TROOP-ZONE-ISALIVE-FILTER — troop zone queries ignore a zone whose anchor is gone

**Status:** ✅ done (PR #245)

Formalizes the `dev/roadmap.md` entry "Zones de troupes — les requêtes ne filtrent pas `isAlive()`", itself
raised by the automated code review of `develop` (issue #238) and left out of `FIX-DCS-OBJECT-NAME-COMPARISON`.
Decisions come from a `grill-with-docs` session held 2026-10-03.

## Problem Statement

CTLD zones can be **anchored** to a DCS object (a ship, a convoy, a unit): the zone then follows its anchor.
A troop zone is normally removed the moment its anchor dies (`S_EVENT_DEAD`, ADR 0021). But an anchor can
disappear without a death event — a group destroyed or removed by a mission script, for instance — and the zone
then stays registered at its anchor's last known position.

For logistic zones this case is already handled: their position and coalition queries skip a zone whose anchor no
longer exists. Troop zones share the same base class and the same `isAlive()` check, but none of their eight
position and coalition queries consults it. Players can still board, drop or extract troops in a zone whose ship
sank or whose convoy vanished (for instance hovering over open water), AI transports can still be sent to pick up
or drop at it, and waypoint zones keep attracting spawned troops.

This is defence in depth, not a defect observed in play: the visible behaviour changes only when an anchor has
disappeared without a death event.

## Solution

Every troop-zone query that looks a zone up by position, coalition or unit ignores a zone whose anchor no longer
exists, exactly as the logistic-zone queries already do. The lookup of a zone by its own registry key is left
alone, like its logistic counterpart. Zones that are not anchored are never filtered out.

## User Stories

1. As a pilot, I want a troop zone whose ship has gone to stop offering me troop loading, so that I am never
   offered a boarding zone over open water.
2. As a pilot, I want a troop zone anchored to a living unit to keep working, so that the filter removes nothing
   it should not.
3. As a pilot, I want a zone that is not anchored to anything (a trigger zone, a static, a FOB) never to be
   filtered out, so that ordinary troop zones are unaffected.
4. As a pilot, I want the troop zone list in the Troop menu to omit a zone whose anchor is gone, so that I do not
   pick an unusable zone.
5. As a pilot, I want "Extract" and "Load" in a zone to apply only to a zone that still exists, so that extraction
   cannot succeed at a phantom position.
6. As a mission maker, I want waypoint zones whose anchor is gone not to attract new troops, so that spawned
   troops do not march to a dead position.
7. As a mission maker, I want drop-off zones whose anchor is gone not to receive AI transports, so that AI
   helicopters are not sent to a vanished ship.
8. As a mission maker, I want AI pickup and drop-off zones to follow the same rule, so that the AI side is
   consistent with the player side.
9. As a CTLD developer, I want the troop-zone queries to use the same condition as the logistic-zone queries, so
   that the two families behave alike.
10. As a CTLD developer, I want the lookup by registry key left unfiltered, so that a caller holding a key can
    still retrieve (and remove) a zone, as for logistic zones.
11. As a CTLD developer, I want a test per query with an anchor that disappears without a death event, so that
    each of the eight filters is covered.
12. As a maintainer, I want the roadmap entry removed once the work lands and a CHANGELOG entry added, so that the
    roadmap lists only open work.

## Implementation Decisions

- **Eight queries filtered:** the troop-zone list by coalition, the zone at a point (and therefore the zone of a
  unit), the waypoint zone at a point, the nearest waypoint zone, the drop-off zone at a point, the AI pickup zone
  at a point, the AI drop-off zone at a point, and the "is this unit in a zone" lookup. Each gets the same added
  condition as the logistic-zone queries: the zone must be active **and** alive.
- **Not filtered:** the lookup of a troop zone by its registry key, and the death handler and the update-event
  payload builder (they must still see every registered zone). This mirrors the logistic side, whose lookup by
  name is unfiltered.
- **Un-anchored zones** answer "alive" unconditionally (existing behaviour of the shared base class), so trigger
  zones, statics, FOBs and scripted zones are untouched.
- **No removal:** a zone found not alive is skipped by the queries, not removed from the registry — removal
  stays the job of the death handler and the static watcher (ADR 0021).
- No config, i18n, schema or catalogue change. No legacy counterpart (anchored troop zones are new to the
  rewrite), so no parity to preserve.

## Testing Decisions

- A good test observes which zone a query returns, never how the check is implemented.
- Seam: a new unit spec on the zone manager, building troop zones directly with an anchor unit whose existence
  the test toggles (the anchor "disappears" with no death event). For each of the eight queries: the zone is
  returned while its anchor exists and is not returned once it is gone. Plus a control: an un-anchored zone is
  returned regardless, and the lookup by registry key still returns a zone whose anchor is gone.
- Written first and seen failing (the eight "gone" cases fail before the change).
- Existing zone specs pass unchanged. No live-DCS test: the change is a pure condition on in-memory zone objects.

## Out of Scope

- Removing a zone whose anchor vanished without an event (a poll for unit anchors was rejected in ADR 0021).
- The other two roadmap items from the review (hard-coded English message, duplicate crate predicates).
- Any change to the logistic-zone queries.

## Further Notes

Source: `dev/roadmap.md` entry "Zones de troupes — les requêtes ne filtrent pas `isAlive()`" (from issue #238's
review). No GitHub issue to close.
