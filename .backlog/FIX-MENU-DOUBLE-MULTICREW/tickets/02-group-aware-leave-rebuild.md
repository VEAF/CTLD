Status: ready

# 02 — Group-aware `onPlayerLeaveUnit` + cleanup migration + L1 tests + rebuild

## Parent

`.backlog/FIX-MENU-DOUBLE-MULTICREW/PRD.md`

## What to build

Make `onPlayerLeaveUnit` aware of multi-crew groups before tearing down the DCS menu.

Before wiping the DCS menu, count how many tracked players in `_players` share the same
`groupId` as the departing unit. Two cases:

- **Not the last player in the group**: remove only `_players[unitName]`. Do not call
  `removeItemForGroup`, do not nil `mmgr.menus[groupId]`. The remaining crew members keep
  their live CTLD menu.
- **Last player in the group**: proceed with full teardown — iterate `menu._activeHandles`,
  call `removeItemForGroup` for each handle, nil `mmgr.menus[groupId]`, remove
  `_players[unitName]`.

As part of this ticket, migrate the existing cleanup path in `onPlayerLeaveUnit` to use
`menu._activeHandles` (introduced in ticket 01) instead of iterating `menuData.children`.

Rebuild `CTLD.lua` via `merge_CTLD.ps1` after all source changes.

## Acceptance criteria

- [ ] When player A leaves a group where player B is still tracked, `removeItemForGroup` is
      NOT called and `mmgr.menus[groupId]` is preserved — verified by L1 test in
      `player_spec.lua`.
- [ ] When the last player in a group leaves, `removeItemForGroup` IS called (once per
      top-level handle) and `mmgr.menus[groupId]` is set to nil — verified by L1 test.
- [ ] `onPlayerLeaveUnit` cleanup uses `menu._activeHandles`, not `menuData.children`.
- [ ] All existing `player_spec.lua` and `menu_manager_spec.lua` tests remain green.
- [ ] `busted tests/ci/` passes clean.
- [ ] `CTLD.lua` rebuilt and committed alongside the source change.

## Blocked by

- `01-active-handles-menu-doubling.md` (`_activeHandles` must exist on `ctld.Menu`)
