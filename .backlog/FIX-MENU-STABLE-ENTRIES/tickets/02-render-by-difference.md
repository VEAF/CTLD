# 02 — Render the menu by difference, park every freed id

**Status:** ✅ done (2026-10-09) · **Type:** AFK

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257. Decisions D1, D2, D3, D5, D6.
Reference implementation: VMCT `veafRadio.RadioMenuBuilder` (`_render`, `_removeEntry`, `rebuild`), VEAF/VEAF-Mission-Creation-Tools#1113.

Files: `src/CTLD_menu.lua` (`refreshMenuForGroup`, `_rebuildMenuNode`, `_rebuildPagedChildren`, `_wipeGroupHandles`), `src/CTLD_player.lua` (last-occupant teardown), `tests/ci/helpers/dcs_stubs.lua` or a dedicated double, `tests/ci/unit/menu_manager_spec.lua`.

## What to build

- A `missionCommands` double that hands out ids as measured (one global pool, last freed first reused) and lets a spec click an id captured before a refresh.
- A rendered mirror per group (D6), key = parent key + type + label + occurrence index (D1).
- The render step builds the rendered tree (enabled filter, order, pagination), creates what appeared, then removes what disappeared, deepest first.
- Every removal is followed by an inert command for the parking group id (D5).
- Commands go through one stable dispatcher resolving the current node at click time (D2).
- An insertion recreates the siblings that follow it, so the declared `order` holds (D3, if confirmed as recommended).
- The last-occupant teardown goes through the manager, which removes and parks every live entry and drops the mirror.

## Acceptance criteria

- [x] busted, written first and seen failing on `develop`: after an identical refresh, a click captured before it fires the same command (test 1 of #257); after a removal and a creation, a click on the removed entry fires the parked command (test 9b); a branch cleared and refilled identically makes no DCS call; a changed argument under an unchanged label runs the new argument without recreating the entry; a submenu turned command parks every id it freed.
- [x] Each fix mutation-checked (spec fails with the parking line removed, and with the reuse disabled).
- [x] Ordering and pagination specs pass unchanged, or are adapted to D3 with the reason in the PR.
- [ ] luacheck clean; `busted` green.

## Blocked by

- D1, D2, D3 confirmed.
