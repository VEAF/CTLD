# 02 — Troop zone removal on anchor death compares names

**Status:** ✅ done (PR #NN) · **Type:** AFK

## Parent

[PRD — FIX-DCS-OBJECT-NAME-COMPARISON](../PRD.md). Source: GitHub issue #238. Stories 7-10, 13, 14.

## What to build

In the zone manager's death handler, the unit/group anchor branch compares the anchor's name (read safely)
with the dead unit's name instead of comparing the stored DCS object with the event's initiator. The
stored-anchor-name branch is untouched.

Test first: rewrite the anchor-death case of the troop-zone scripted API spec so the event initiator is a
distinct object carrying the anchor's name (it currently passes the same table, true by construction). Add
the negative case (different name, zone stays). Watch the positive case fail, then fix.

## Acceptance criteria

- [ ] The anchor-death test uses a distinct initiator object and fails before the fix.
- [ ] A different-named death leaves the zone registered.
- [ ] Moving-Zone-anchored and logistic-zone removal tests pass unchanged.
- [ ] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
