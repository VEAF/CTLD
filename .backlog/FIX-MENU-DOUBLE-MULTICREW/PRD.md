Status: ready

# FIX-MENU-DOUBLE-MULTICREW — F10 menu duplication and multi-crew menu loss

## Problem Statement

Transport pilots encounter two identical "CTLD" entries in the F10 menu. When two entries are
present, neither is interactive — the player cannot access any CTLD function for the rest of the
mission.

This is reproducible on any multi-crew aircraft where pilot and copilot share the same DCS group
(e.g. CH-47): the copilot joining the slot triggers a second menu build for a group that already
has a live CTLD menu in DCS. Because the old DCS handles are discarded before the cleanup runs,
the old menu items are never removed and the new ones stack on top.

A second, related issue: when one member of a multi-crew group leaves the slot, the CTLD menu is
torn down for the entire group — including the crew members who are still flying. Those remaining
players lose their menu with no way to recover it short of leaving and re-entering the slot.

## Solution

Two surgical fixes to `ctld.Menu` and `CTLDPlayerManager`:

**Fix 1 — Decouple DCS handles from the logical tree model.**
`ctld.Menu` gains a dedicated `_activeHandles` list that tracks the live top-level DCS handles
independently of `menu.children`. `refreshMenuForGroup` uses this list for cleanup before each
rebuild and repopulates it after. `buildMenu` can safely reset `menu.children` without losing
the handles needed for the next cleanup pass.

**Fix 2 — Group-aware leave logic.**
`onPlayerLeaveUnit` checks whether other players from the same DCS group are still tracked before
tearing down the DCS menu. If crew members remain, only the departing player's tracking entry is
removed. The DCS menu is preserved. Full cleanup runs only when the last tracked player in the
group leaves.

Both fixes align `onPlayerLeaveUnit`'s cleanup path to use `_activeHandles` (consistent with
the new design, eliminates a divergent code path).

## User Stories

1. As a transport pilot, I want the CTLD F10 menu to appear exactly once after I enter my slot,
   so that I can access CTLD functions without the menu being non-interactive.

2. As a copilot boarding a multi-crew aircraft (e.g. CH-47) after the pilot is already seated,
   I want the CTLD menu to be usable when I join, so that I can participate in logistics
   operations from my slot.

3. As a pilot in a multi-crew aircraft, I want the CTLD menu to remain available after my copilot
   leaves the slot, so that I do not lose access to CTLD mid-mission due to crew changes.

4. As a copilot, I want the CTLD menu to remain available after the pilot leaves the slot, so
   that I can continue operations without re-slotting.

5. As a transport pilot who leaves and re-enters a slot, I want the CTLD menu to appear exactly
   once when I re-enter, so that there is no duplication from the previous session.

6. As a mission maker, I want the CTLD menu system to handle crew changes transparently, so that
   I do not need to add workarounds in mission triggers.

## Implementation Decisions

- **`_activeHandles` field on `ctld.Menu`**: a flat list (array) of opaque DCS handles for the
  top-level items currently rendered in DCS for this group. Initialized to `{}` at menu creation.
  Top-level only — DCS cascades removal to child items when a parent submenu is removed, so
  tracking deeper handles is unnecessary.

- **`refreshMenuForGroup` cleanup path**: iterates `_activeHandles` (not `menu.children`) to call
  `removeItemForGroup` on each live handle before rebuilding. After rebuild, repopulates
  `_activeHandles` with the new top-level handles. The memory model reset in `buildMenu` has no
  effect on cleanup because handles are no longer stored in `menu.children` nodes only.

- **`buildMenu` unchanged in structure**: `menu.children = {}` stays as-is. The fix is in where
  handles live, not in how `buildMenu` resets the model.

- **`onPlayerLeaveUnit` — last-player check**: before tearing down the DCS menu, iterate
  `_players` to count how many tracked players share the same `groupId`. If count > 1 (the
  departing player is not the last), skip DCS cleanup and `mmgr.menus[groupId] = nil`; remove
  only `_players[unitName]`. If count == 1, proceed with full cleanup using `_activeHandles`.

- **`onPlayerLeaveUnit` cleanup path**: migrated to use `menu._activeHandles` instead of iterating
  `menuData.children`, consistent with the new design.

- No new public API on `ctld.MenuManager` or `ctld.Menu`. `_activeHandles` is internal.

## Testing Decisions

A good test asserts observable external behavior (which DCS calls were made and when) without
coupling to internal field names beyond what the fix introduces:

- **`removeItemForGroup` called before rebuild**: after a second `buildMenu` for the same groupId,
  the mock must record a `removeItemForGroup` call with the handle from the first build before any
  new `addSubMenuForGroup` call.

- **`removeItemForGroup` NOT called when a non-last crew member leaves**: after player A leaves a
  group where player B is still tracked, the mock must record no `removeItemForGroup` call.

- **`removeItemForGroup` IS called when the last crew member leaves**: the standard teardown path.

Prior art: `tests/ci/unit/menu_manager_spec.lua` (covers `createMenuForGroup`,
`refreshMenuForGroup`, pagination, and debounced refresh with mocked `missionCommands`) and
`tests/ci/unit/player_spec.lua` (covers `CTLDPlayerManager` event handlers with mocked DCS
environment). New cases extend these two specs.

A **MT-** entry in `tests/manual_test_sequences.md` covers the live multi-crew scenario:
pilot enters CH-47, copilot joins after a few seconds, verify single menu; pilot leaves, verify
copilot menu survives; copilot leaves, verify clean teardown.

## Out of Scope

- Multi-crew scenarios where a remaining crew member should receive a *rebuilt* menu after
  a slot change (e.g. new pilot with different capabilities). The fix preserves the existing
  menu; capability changes on re-slot are a separate feature.
- `ctld.initialize()` called twice (no guard against double initialization). A separate lot.
- Any change to the pagination or ordering logic in `ctld.MenuManager`.

## Further Notes

The duplication is silent at the Lua level — no error is logged. The only observable symptom
is the doubled F10 entry. The fix should add an `INFO` log line when `_activeHandles` cleanup
removes at least one handle, to make future diagnoses easier.
