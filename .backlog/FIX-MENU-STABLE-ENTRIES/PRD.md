# FIX-MENU-STABLE-ENTRIES — an F10 entry that did not change is never recreated

**Status:** 🔨 in progress — D1-D4 confirmed by Zip as recommended (2026-10-09); tickets 02 and 03 done, 04 (live DCS) waiting for Zip

Formalizes GitHub issue #257 (Zip, 2026-10-09), from wrong F10 commands still reported by players after ADR 0015 (FullGas, 2026-10-09).
Supersedes part of ADR 0015: a new ADR is part of the lot.
Replanned on 2026-10-09 evening with the full measurement and the VMCT implementation (VEAF/VEAF-Mission-Creation-Tools#1113), which answer what the first version left open.

## Problem Statement

A player clicks an F10 CTLD command and another one fires.
ADR 0015 (2026-09-16) attributed it to a refresh landing while the player is mid-navigation, and answered with a delay: an ambient refresh wipes the group's CTLD menu at once and rebuilds it 4 s later.
Players still report wrong commands.

## What DCS does — measured 2026-10-09

Single player, raw `missionCommands` (no CTLD, no VEAF), mission restarted before each test, clicks with the mouse, the change applied from the fiddle hook while the player held `TEST MENU > Liste` (A, B, C, D) open.
Kit and first tables in #257.

| # | Change applied while the list is on screen | Clicked | Fired |
|---|---|---|---|
| 1 | remove A, B, C, D, then add them again, identical | B | **C** |
| 7 | remove A, then add X and Y elsewhere; menu reopened fresh | X, Y | X, Y |
| 9a | remove A, then add E | B | B |
| 9b | remove A, then add E | A | **E** |
| P1 | global menu: remove A, add a command for group 999999 (no such group), then add E | A | the group-999999 command |
| P2c | group menu: remove A, then add E | A | **E** |
| P2 | group menu: remove A, add a command for group 999999, then add E | A | the group-999999 command |

What it establishes:

- DCS tracks each entry by an internal id, not by its position nor its label; an untouched entry keeps its id whatever happens around it (9a).
- A removed entry's id goes to the **next entry created**; the reuse order fits "last freed, first reused" (test 1: A, B, C, D recreated take D's, C's, B's, A's ids, so B's old id now runs C).
- **One pool for the whole server**: an id freed in the global menu went to a command created for another group (P1). So a stale click can fire another group's command.
- A freshly opened menu is always right; only a screen open across the change is wrong.
- **Parking works**: a command created for a group id no player holds, right after a removal, takes the freed id; a stale click on the removed entry then runs that inert command, in global and group menus (P1, P2).

Checked in VMCT on the real `veafRadio` code (hot-loaded in a running mission): with rendering by difference plus parking, a refresh with nothing changed makes no DCS call, an addition while a submenu is held open makes one call and the click fires what was shown, a replacement while the entry is on screen makes the click fire nothing.

Not measured, and not needed once every removal is parked: how long a freed id stays reusable, and coalition menus (CTLD only uses group menus).

## Cause in CTLD

`ctld.MenuManager:refreshMenuForGroup` (`src/CTLD_menu.lua:251`) removes every top-level CTLD handle of the group and recreates the whole tree: test 1 at the scale of the whole menu, on every refresh.
The ambient delay of ADR 0015 only moves the moment: the wipe frees the ids, the rebuild 4 s later hands them out again, and a screen opened before the wipe still points at them.
ADR 0015 considered and rejected targeted removal for consistency with the atomic model; the measurement shows the atomic model is what reassigns the ids.

## Solution

1. **Render by difference**: build the rendered tree (enabled filter, `order` sort, pagination with its "→ Next Page" submenus), compare it by key with what is live in DCS for the group, create what appeared, remove what disappeared, leave every other entry and its id alone.
2. **Park every freed id**: right after each `removeItemForGroup`, create an inert command for a group id no player can hold (VMCT uses `999999`), with a unique label and a callback that only logs at debug level. A submenu's children are removed one by one before it, each id parked.
3. **Removals after creations** within one refresh, so nothing created in that refresh can take an id before it is parked.

VMCT's implementation is the reference: `RadioMenuBuilder:_render`, `_removeEntry`, `rebuild` in `src/scripts/veaf/veafRadio.lua` (VEAF/VEAF-Mission-Creation-Tools#1113), with its specs in `test/lua/test_veafRadio.lua` (`TestVeafRadioIncrementalRender`).

## Decisions — recommendation each, to confirm

- **D1 — What identifies an entry across two renders.**
  Recommendation: parent key + type (submenu / command) + label, in the **rendered** tree, so "→ Next Page" submenus are diffed like the rest; two siblings with the same label take an occurrence index (`#2`).
  The type must be in the key: a submenu turned into a command of the same label must leave through the normal removal (children first, each id parked), never through an inline replacement that parks one id for several freed (found in VMCT's review).
  The occurrence index shifting when an earlier twin disappears only costs a recreation, which parking makes safe.
- **D2 — An entry whose label did not change but whose callback or argument did.**
  Recommendation: late binding. CTLD wraps every callback in a fresh closure (`wrapped`, `src/CTLD_menu.lua:325`) and `clearBranch` recreates the nodes on each refresh, so comparing callbacks by reference, as VMCT does, would recreate every command every time.
  The function handed to DCS is one stable dispatcher; its argument is the entry's key; at click time it resolves the current logical node for that group and key and calls its function with its argument.
  A node gone at click time: nothing runs, an info log.
- **D3 — Sibling order.**
  `missionCommands` has no insert-at: a created entry goes after its existing siblings.
  The first version of this PRD left (a) recreate the followers / (b) append / (c) key by slot open until the measurement.
  Parking changes the trade-off: recreating an entry is now **safe** (a stale click on it fires nothing) where it used to fire a wrong command.
  Recommendation: **(a)**, recreate the siblings that follow an insertion point, so the declared `order` holds and the ENABLED convention keeps its promise (a re-enabled node returns to its F-key slot) — legacy parity.
  VMCT chose (b) plus stable pages because its menus have no declared order; CTLD's do.
  Pagination follows from (a): an entry crossing a page boundary is recreated on its new page.
- **D4 — The ambient delay of ADR 0015 goes.**
  Recommendation: every refresh applies the difference at once, behind the existing `DEBOUNCE_S` coalescing; `AMBIENT_REBUILD_DELAY_S`, the ambient wipe and `_pendingAmbient` are removed; `runUrgent` / `_urgentGroupId` go too unless the debounce still needs them.
  A new ADR (0027) records the measurement and supersedes ADR 0015's decision.
- **D4 bis — `runUrgent`'s error isolation** (found while implementing, decided by Zip 2026-10-09).
  `runUrgent` also wrapped its body in `pcall` + log, and several call sites run inside a timer callback a raise would stop for good (the flight-state and slingload pollers).
  Decided: the urgency goes, the isolation stays as `ctld.utils.protectedCall(context, fn)` at the same call sites.
- **D5 — The reuse of a freed id (case 2).** Settled by the measurement: parking, in this lot (Solution 2).
- **D6 — Handles of every entry.** Settled: a rendered mirror per group, key → `{ handle, type, depth }`; today `menu._activeHandles` keeps only top-level handles and command handles are discarded (`src/CTLD_menu.lua:340`).

## Implementation deviations (2026-10-09)

- **Removals before creations, within one level** (Solution 3 said after): DCS addresses an entry by its label path, so a recreated entry must not coexist with its old self under one path; parking each freed id at once keeps the goal of Solution 3 (nothing created takes an unparked id).
- **Removal by the handle DCS returned**: the developer doc records that `removeItemForGroup` ignores a label path rebuilt by the caller; the mirror keeps each returned handle, and the busted double honours only the handles it issued.
- **`_sortByOrder` made really stable**: `table.sort` is not, so siblings sharing an `order` could change places between two refreshes and be recreated for nothing.
- **Root level not paginated**, as before; every submenu is.
- **The dispatcher runs the node of the last refresh**, not the logical tree at click time: between a model change and its debounced refresh, the click runs what the player saw.

## Implementation notes (from the current code)

- `ctld.Menu` is the logical model; callers mutate it (`clearBranch` + `addCommand`, `setBranchEnabled`, `removeMenuBranch`) then call `refresh`.
  Outside `src/CTLD_menu.lua`, only the last-occupant teardown of `src/CTLD_player.lua:512-516` touches `missionCommands` (it removes `menu._activeHandles` itself): it should go through the manager, which removes every live entry, parks each id and drops the mirror.
- Never remove the group's whole menu (`nil` path): Ground Crew / ATC entries are DCS's.
- DCS reuses a numeric group id for the next occupant of a slot (#152): the teardown dropping the mirror is what keeps the next occupant from inheriting a mirror of entries that no longer exist.
- The parking group id must be one no slot can hold; check CTLD's own group id ranges before reusing VMCT's `999999`, and share the constant if both scripts run in one mission (two parkings on one id are harmless: they are inert).

## Testing Decisions

- busted: a `missionCommands` double that hands out ids as measured (one global pool, freed ids reused last-freed-first) and lets a spec "click" an id captured before a refresh.
  Written first and seen failing on `develop`: after an identical refresh, a click captured before it fires the same command (test 1); after a removal and a creation, a click on the removed entry fires the parked command, not the new one (test 9b).
  Plus: a branch cleared and refilled identically makes no DCS call; a changed argument under an unchanged label runs the new argument without recreating the entry (D2); an insertion recreates exactly the followers (D3); a submenu turned command parks every id it freed (D1).
- Each fix mutation-checked: the spec must fail with the parking line removed, and with the reuse disabled.
- Live DCS (Zip): ticket 04.

## Out of Scope

- Any change to what the menu contains, its order or its labels.

## Further Notes

Source issue: #257 — `Fixes #257` once parking is in.
VMCT side: lot `FIX-RADIO-MENU-ID-RECYCLING`, trap `f10-menu-entry-id-is-recycled` in its `known-limitations.yaml`.
