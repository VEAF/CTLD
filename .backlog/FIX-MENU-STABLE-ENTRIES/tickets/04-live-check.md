# 04 — Live check in a CTLD mission

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257.

## What to check

On the built `CTLD.lua` of the branch, in a test mission:

1. Hold `Troop Commands` (or any CTLD submenu) open on a transport parked in a logistic zone; trigger an ambient refresh (another aircraft lands nearby, a crate is spawned near by another player); click an entry; the logged command is the one clicked.
2. Same with `Crate Commands > Load Crate` while a crate is added nearby: an existing entry still fires its own crate.
3. Same with a list long enough to page, while one entry is added before the page boundary.

## Acceptance criteria

- [ ] The three checks give the clicked command, recorded with the test table in the PR.
- [ ] Any case that still misfires is a case-2 event (removal + creation) and is noted for the follow-up lot.

## Blocked by

- 02, 03.
