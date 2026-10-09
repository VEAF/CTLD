# FIX-MENU-STABLE-ENTRIES — an F10 entry that did not change is never recreated

**Status:** 🧑 waiting-human — design decisions D1-D6 to settle (a `grill-with-docs` session) before the tickets are final

Formalizes GitHub issue #257 (Zip, 2026-10-09), from wrong F10 commands still reported by players after ADR 0015 (FullGas, 2026-10-09).
Supersedes part of ADR 0015: a new ADR is part of the lot.

## Problem Statement

A player clicks an F10 CTLD command and another one fires.
ADR 0015 (2026-09-16) attributed it to a refresh landing while the player is mid-navigation, and answered with a delay: an ambient refresh wipes the group's CTLD menu at once and rebuilds it 4 s later.
Players still report wrong commands.

The measurement of #257, on raw `missionCommands` without CTLD or VEAF, gives the mechanism:

- DCS tracks each entry by an internal id, not by its position nor its label.
- The id of a removed entry is reused by the next entry created, last removed first: removing A, B, C, D then recreating A, B, C, D identically makes a click on B fire C (test 1).
- A screen that stays open across the change keeps the old ids; a freshly opened menu is always right.
- Removing A and creating E makes a stale click on A fire E (test 9b); a stale click on B, untouched, still fires B (test 9a).

CTLD hits this on every refresh.
`ctld.MenuManager:refreshMenuForGroup` (`src/CTLD_menu.lua:251`) removes every top-level CTLD handle of the group and recreates the whole tree.
Every id is reassigned at once: test 1, at the scale of the whole menu.
The ambient delay of ADR 0015 only moves the moment: the wipe frees the ids, the rebuild 4 s later hands them out again, and a screen opened before the wipe still points at them.
ADR 0015 considered and rejected targeted removal, for consistency with the atomic model the rewrite chose; the measurement shows the atomic model is what reassigns the ids.

Two cases follow:

1. **Rebuild of an unchanged entry** — the frequent one: a refresh triggered by a zone change, a nearby crate, a poll, recreates dozens of entries that did not change.
2. **Removal of one entry and creation of another** — rarer: the new entry inherits the removed one's id, and a stale click on the removed entry fires it.

## Solution

Render the menu by difference: compare the tree to display with the one live in DCS, remove only what disappeared, create only what appeared, leave every other entry and its id alone.
That removes case 1.
Case 2 needs a mechanism that keeps a new entry from inheriting a just-freed id; it is not designed yet, VEAF-Mission-Creation-Tools has the same problem in `veafRadio` and will work on it, so its design is shared (D5).

## Decisions to settle

Each with a recommendation; none is final until the grilling session.

- **D1 — What identifies an entry across two renders.**
  Recommendation: its path of labels plus its type (submenu / command), within the **rendered** tree (after `enabled` filtering, `order` sorting and pagination, so the DCS-only "→ Next Page" submenus are diffed like the rest).
  Open point: two siblings with the same label (two crates of the same type in Load Crate, two vehicles of the same type in Pack Vehicle) need an occurrence index in the key, and that index shifts when an earlier twin disappears.
- **D2 — An entry whose label did not change but whose callback or argument did.**
  Recommendation: late binding — the function given to DCS resolves the current logical node from its key at click time and calls that node's function with that node's argument, so a changed argument never requires recreating the DCS entry.
  To check: what a click does when the node is gone (expected: nothing, with an info log).
- **D3 — Sibling order.**
  `missionCommands` has no insert-at: a created entry goes after its existing siblings.
  Options: (a) recreate the siblings that follow the insertion point, so the declared `order` holds, at the price of case 2 for them; (b) let new entries land last until the parent is rebuilt; (c) key entries by slot rather than by label (slot k of a parent always runs the current k-th child; only a slot whose label changed is recreated).
  Recommendation: decide after D5's measurement, since (a) and (c) both lean on what DCS does with freed ids.
- **D4 — The ambient delay of ADR 0015 goes.**
  Recommendation: with diffing, every refresh applies at once, urgent or ambient; `AMBIENT_REBUILD_DELAY_S`, the ambient wipe and `_pendingAmbient` are removed, the `DEBOUNCE_S` coalescing stays.
  A new ADR (0027) records the measurement and supersedes ADR 0015's decision; ADR 0015 is marked superseded.
- **D5 — Case 2, the reuse of a freed id.**
  Recommendation: in this lot, only the measurement that a design needs (ticket 01): is the reuse per group, per coalition or global; is it strictly last-freed-first; does creating the new entry before removing the old one avoid it; does removing a submenu free its children's ids.
  The fix itself waits for the design shared with VMCT, and is a later lot.
- **D6 — Handles of every entry, not only the top level.**
  Today `menu._activeHandles` keeps only top-level handles, and command handles are discarded (`src/CTLD_menu.lua:340`).
  Diffing needs the live handle of every rendered entry; recommendation: a rendered-tree mirror per group, key → `{ handle, type }`.

## Implementation notes (from the current code)

- `ctld.Menu` is the logical model; callers mutate it (`clearBranch` + `addCommand`, `setBranchEnabled`, `removeMenuBranch`) then call `refresh`; outside `src/CTLD_menu.lua`, only the last-occupant teardown of `src/CTLD_player.lua:512-516` touches `missionCommands` (it removes `menu._activeHandles` itself), so the change is contained in the manager plus that teardown, which should call the manager instead.
- `clearBranch` + re-add creates new node tables with new closures at each refresh: node identity cannot be the key, hence D1.
- Never remove the group's whole menu (`nil` path): Ground Crew / ATC entries are DCS's (`_wipeGroupHandles` comment).
- The urgent / ambient detection (`runUrgent`, `_urgentGroupId`) is still needed for the debounce, or not at all if D4 drops the distinction entirely: settle with D4.

## Testing Decisions

- busted: a `missionCommands` double that hands out ids the way the measurement says DCS does (freed ids reused last-freed-first) and lets a spec "click" an id captured before a refresh.
  Written first and seen failing on `develop`: the identical-rebuild case (test 1) fires another command; after the change it fires the same one.
  Same for an ambient refresh, a branch cleared and refilled with the same entries, a page boundary moved by one entry.
- Live DCS (Zip, with a running mission): the #257 reproduction kit, then the same on CTLD — hold `Troop Commands` open while a zone change triggers an ambient refresh, click, check the logged command.

## Out of Scope

- The fix of case 2 (D5): shared design with VMCT, later lot.
- Any change to what the menu contains, its order or its labels.

## Further Notes

Source issue: #257. The PR references it with `Refs #257` while case 2 stays open, `Fixes #257` only if D5 is solved in the lot.
Reproduction kit: in #257.
