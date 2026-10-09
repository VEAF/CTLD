# 04 — Live check in a CTLD mission

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257.

## What to check

On the built `CTLD.lua` of the branch, in a test mission:

1. Hold `Troop Commands` (or any CTLD submenu) open on a transport parked in a logistic zone; trigger an ambient refresh (another aircraft lands nearby, a crate is spawned near by another player); click an entry; the logged command is the one clicked.
2. Same with `Crate Commands > Load Crate` while a crate is added nearby: an existing entry still fires its own crate.
3. Same with a list long enough to page, while one entry is added before the page boundary.
4. Same while the clicked entry itself is replaced (a crate picked up by another player while its entry is on screen): the click fires nothing, the parked command logs it.

## Acceptance criteria

- [ ] The three checks give the clicked command, recorded with the test table in the PR.
- [ ] Check 4 fires nothing; any case that still misfires is reported in #257 with its table.

## Blocked by

- 02, 03.
