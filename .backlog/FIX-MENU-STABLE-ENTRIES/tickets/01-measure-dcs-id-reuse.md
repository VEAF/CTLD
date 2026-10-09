# 01 — Measure how DCS reuses a freed menu id

**Status:** ✅ done (2026-10-09, Zip + Claude, from the VMCT session) · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FIX-MENU-STABLE-ENTRIES](../PRD.md). Source: GitHub issue #257. Decisions D3, D5.

## Answers

The tables are in the PRD, "What DCS does — measured 2026-10-09".

1. **Scope of reuse** — one pool for the whole server: an id freed in the global menu went to a command created for another group (P1); group menus recycle as well (P2c).
2. **Order of reuse** — consistent with last freed, first reused (test 1: B fired C after an identical rebuild).
3. **Create before remove** — not measured; superseded by parking, which consumes each freed id right after its removal whatever the order.
4. **Submenus** — not measured directly; the implementation removes a submenu's children one by one before it and parks each id, which covers it whatever DCS does.
5. **Delay** — not measured; parking makes it irrelevant.

And the measurement this ticket did not plan, which settles D5: a command created for a group no player holds, right after a removal, takes the freed id, in global and group menus (P1, P2).

## Acceptance criteria

- [x] Each question answered with the table of tests, in #257 and in the PRD.
- [ ] The busted `missionCommands` double of ticket 02 reproduces the measured behaviour (moved to ticket 02).
