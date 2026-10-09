# ADR 0027 — An F10 entry that did not change is never recreated; every freed id is parked

**Date:** 2026-10-09
**Status:** Accepted — supersedes [ADR 0015](0015-safe-by-default-ambient-menu-refresh.md)
**Lot:** `FIX-MENU-STABLE-ENTRIES` (issue #257).

## Context

ADR 0015 answered a misfiring F10 click (a C-130 asked for "Load Standard Group" and dropped red smoke) with a delay: a background refresh wiped the group's CTLD menu at once and rebuilt it 4 s later.
Players still reported wrong commands.

Zip measured what DCS does on 2026-10-09, single player, raw `missionCommands` (no CTLD, no VEAF), the change applied while `TEST MENU > Liste` (A, B, C, D) was held open on screen:

| # | Change applied while the list is on screen | Clicked | Fired |
|---|---|---|---|
| 1 | remove A, B, C, D, then add them again, identical | B | **C** |
| 7 | remove A, then add X and Y elsewhere; menu reopened fresh | X, Y | X, Y |
| 9a | remove A, then add E | B | B |
| 9b | remove A, then add E | A | **E** |
| P1 | global menu: remove A, add a command for group 999999 (no such group), then add E | A | the group-999999 command |
| P2c | group menu: remove A, then add E | A | **E** |
| P2 | group menu: remove A, add a command for group 999999, then add E | A | the group-999999 command |

DCS tracks each entry by an internal id.
An untouched entry keeps its id whatever happens around it (9a).
A removed entry's id goes to the **next entry created**, last freed first reused (test 1: the recreated A, B, C, D took D's, C's, B's, A's ids), from **one pool for the whole server**: an id freed in the global menu went to a command created for another group (P1).
A screen left open keeps the ids it was drawn with, so a click on it runs whatever holds that id now; a freshly opened menu is always right.
And a command created for a group no player holds, right after a removal, takes the freed id (P1, P2): **parking** works.

So ADR 0015's ambient path was test 1 at the scale of the whole menu, delayed: the wipe freed every id, the rebuild 4 s later handed them out again, and a screen opened before the wipe still pointed at them.
The urgent path was test 1 without the delay.

VMCT shipped the same fix first (`veafRadio.RadioMenuBuilder`, VEAF/VEAF-Mission-Creation-Tools#1113); this ADR follows it, with the differences below.

## Decision

1. **Render by difference.**
   `refreshMenuForGroup` builds the rendered tree (enabled filter, `order` sort, pagination with its "→ Next Page" submenus), compares it with a mirror of what is live in DCS for the group (`menu._rendered`), creates what appeared and removes what disappeared.
   Every other entry, and its id, is left alone.
   An entry's key is its parent's key + submenu/command + label, with `#n` for the n-th twin, taken in the rendered tree (D1).
   The type is in the key, so a submenu turned command of the same label leaves through the normal removal, children first, each id parked.
2. **Park every freed id.**
   Right after each `removeItemForGroup`, an inert command is created for group `999999`, with a unique label and a callback that only logs.
   It takes the freed id, so a stale click on the removed entry runs it and nothing else.
   CTLD's own group ids (`ctld.utils.getNextUniqId`) start at 1 and only name AI groups, which have no F10 menu; VMCT parks on the same id, which is harmless (the parked commands are inert).
3. **One stable dispatcher (D2).**
   Every command is handed the same function, `ctld.MenuManager._dispatch`, with `{ groupId, key }` as argument.
   At click time it runs the node rendered under that key at the last refresh, so a new callback or argument under an unchanged label needs no recreation.
   VMCT compares callbacks by reference instead; CTLD cannot, since every section builder recreates its nodes and closures on each refresh.
   A key no longer rendered runs nothing and logs at INFO.
4. **Declared order holds (D3).**
   `missionCommands` has no insert-at: a created entry goes after its existing siblings.
   The entries kept are the longest run of live entries already in the wanted order; the siblings after an insertion point are recreated, which parking makes safe.
   A re-enabled node returns to its F-key slot, as the ENABLED convention promises.
   VMCT appends instead, its menus having no declared order.
5. **Removals before creations, within one level.**
   DCS addresses an entry by its label path, so a recreated entry must not coexist with its old self under the same path.
   Parking consumes each freed id at once, so no entry created afterwards can take it.
   (The PRD put removals after creations; that order mattered only without immediate parking.)
6. **Removal by the handle DCS returned.**
   `removeItemForGroup` ignores a label path rebuilt by the caller, so the mirror keeps the handle each add returned.
7. **No ambient delay (D4).**
   Every refresh applies the difference `DEBOUNCE_S` (0.15 s) after the first request, coalescing bursts.
   `AMBIENT_REBUILD_DELAY_S`, the ambient wipe, `_pendingAmbient`, `runUrgent`, `_urgentGroupId` and the `{ urgent = true }` option go.
   The `pcall` + log that `runUrgent` gave its call sites stays, as `ctld.utils.protectedCall`: several of them run inside a timer callback that a raise would stop for good.
8. **Teardown through the manager.**
   When a group's last crew member leaves, `teardownGroup` removes every live entry (each id parked), drops the menu with its mirror and cancels any pending refresh.
   DCS reuses a numeric group id for the next occupant of a slot (#152), who starts from an empty mirror.

## Consequences

- An unchanged entry clicked from a screen left open fires itself, whatever changed around it.
- A removed or recreated entry clicked from a screen left open fires a parked command: nothing happens, an INFO line is logged.
  That is the remaining cost: a player whose entry was replaced while he looked at it must click again.
- Parked commands accumulate under group 999999, one per removal, for the life of the mission; they are never shown and never removed (removing one would free its id again).
- A refresh that changes nothing makes no DCS call, so background polls no longer cost a rebuild.
- `_sortByOrder` is now really stable (ties broken on insertion order): `table.sort` is not, and an unstable order would have recreated untouched entries on every refresh.
- The root level stays unpaginated, as before; every submenu is paginated.

## Not measured

How long a freed id stays reusable, coalition menus (CTLD only uses group menus), the order in which DCS frees a submenu's children.
None matters once every removal is parked and a submenu's children are removed one by one before it.

## Verification

busted, against a `missionCommands` double that recycles ids as measured (`tests/ci/helpers/mission_commands_double.lua`): `tests/ci/unit/menu_stable_entries_spec.lua` fails on the wipe-and-rebuild code (test 1 reproduces "B fires C") and passes on this one; each fix is mutation-checked (parking removed, entry reuse disabled, tie-break removed).
Live check in a CTLD mission: ticket 04 of the lot.
