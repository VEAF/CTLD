# 01 — Troop zone queries skip a zone whose anchor is gone

**Status:** ✅ done (PR #245) · **Type:** AFK

## Parent

[PRD — FIX-TROOP-ZONE-ISALIVE-FILTER](../PRD.md). Stories 1-12.

## What to build

Add the "zone is alive" condition (the one the logistic-zone queries already use) to the eight troop-zone
queries: the list by coalition, the zone at a point, the waypoint zone at a point, the nearest waypoint zone,
the drop-off zone at a point, the AI pickup zone at a point, the AI drop-off zone at a point, and the unit-in-zone
lookup. The lookup by registry key, the death handler and the update-event payload builder stay unfiltered.

Test first, in a new zone-manager unit spec: troop zones built with an anchor unit whose existence the test
toggles; for each of the eight queries, returned while the anchor exists and not returned once it is gone; an
un-anchored zone is always returned; the lookup by registry key still returns a zone whose anchor is gone. Watch
the eight "gone" cases fail, then fix.

Finish the lot: remove the roadmap entry, add the CHANGELOG entry, rebuild `CTLD.lua` and confirm the i18n
dictionaries are unchanged, set the index line to `merged (PR #245)` and the statuses to done, open the PR.

## Acceptance criteria

- [ ] The eight "anchor gone" cases fail before the change and pass after it (test committed first).
- [ ] Un-anchored zones and the lookup by registry key behave as before.
- [ ] Existing zone specs pass unchanged; luacheck clean; `busted` green.
- [ ] Roadmap entry removed, CHANGELOG entry added, dictionaries unchanged, index line `merged (PR #245)`.

## Blocked by

None - can start immediately.
