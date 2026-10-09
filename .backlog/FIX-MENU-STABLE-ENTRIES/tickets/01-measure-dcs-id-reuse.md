# 01 — Measure how DCS reuses a freed menu id

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257. Decisions D3, D5.

## What to measure

With the #257 reproduction kit (fiddle hook, a player holding a submenu open), extended with `*ForGroup` and `*ForCoalition` variants:

1. **Scope of reuse.** An entry removed in group A's menu, then an entry created in group B's (or the coalition's) menu: does a stale click in A fire B's entry?
2. **Order of reuse.** Remove A, B, C, D, create one entry: does it take D's id (last freed first), A's, or another?
3. **Create before remove.** Create E, then remove A: does a stale click on A fire nothing (E took a fresh id), and does the next creation then inherit A's id?
4. **Submenus.** Remove a submenu holding two commands, create one command elsewhere: does it inherit the submenu's id or a child's?
5. **Delay.** Does a freed id stay reusable indefinitely, or only for a while?

## Acceptance criteria

- [ ] Each question answered with the table of tests (change applied, clicked, fired), in #257 and in the PRD's Further Notes.
- [ ] The busted `missionCommands` double of ticket 02 reproduces the measured behaviour.

## Blocked by

None - can start immediately (needs DCS).
