# 02 — Render the menu by difference

**Status:** ⬜ ready once D1, D2, D3, D6 are settled · **Type:** AFK

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257. Decisions D1, D2, D3, D6.

Files: `src/CTLD_menu.lua` (`refreshMenuForGroup`, `_rebuildMenuNode`, `_rebuildPagedChildren`, `_wipeGroupHandles`), `src/CTLD_player.lua` (last-occupant teardown), `tests/ci/helpers/dcs_stubs.lua` or a dedicated double, `tests/ci/unit/menu_manager_spec.lua`.

## What to build

- A `missionCommands` double that hands out ids as DCS does (per ticket 01) and lets a spec click an id captured before a refresh.
- The render step builds the rendered tree (enabled filter, order, pagination), compares it by key with the live mirror of the group, removes what disappeared, creates what appeared, keeps the handle of everything else.
- Command entries resolve their node at click time (D2).
- The last-occupant teardown goes through the manager, which removes every live handle and drops the mirror.

## Acceptance criteria

- [ ] busted, written first and seen failing on `develop`: after an identical refresh, a click captured before it fires the same command (test 1 of #257); a branch cleared and refilled identically keeps every id; a changed argument under an unchanged label runs the new argument without recreating the entry; an entry that disappears is removed and its stale click fires nothing when nothing was created since.
- [ ] Ordering and pagination specs pass unchanged, or are adapted to D3 with the reason in the PR.
- [ ] luacheck clean; `busted` green.

## Blocked by

- 01 (the double must reproduce the measured reuse).
- D1, D2, D3, D6 settled.
