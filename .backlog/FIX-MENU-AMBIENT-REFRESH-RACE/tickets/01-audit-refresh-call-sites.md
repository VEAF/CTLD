# 01 — Audit and classify existing menu-refresh call sites

**Status:** ⬜ ready

See the PRD and **ADR 0015** for why every refresh needs an explicit `urgent` vs ambient
classification going forward.

## What changes

No behavior change in this ticket — it produces the classification table ticket 02 implements
against, so the implementation doesn't have to re-derive call sites mid-flight.

Every menu refresh funnels through one entry point: `ctld.Menu:refresh()`
([CTLD_menu.lua:498](../../src/CTLD_menu.lua#L498)) → `manager:deferredRefreshForGroup(groupId)`
([:95](../../src/CTLD_menu.lua#L95)) → `refreshMenuForGroup(groupId)` ([:112](../../src/CTLD_menu.lua#L112)).
Grep inventory of every `menu:refresh()` / `deferredRefreshForGroup` call as of this lot (re-grep
before implementing — this list is a starting point, not a guarantee nothing else was added since):

| File | Line(s) | Caller context |
|---|---|---|
| `CTLD_crate.lua` | 606, 669, 683, 709, 908, 938, 956, 979, 1051, 2631, 2641, 2770, 2838 | crate load/drop/pack/unpack, hover status, request-equipment/unpack section refreshes |
| `CTLD_jtac.lua` | 1488, 1497, 1525, 1589 | JTAC equipment / command branch refreshes |
| `CTLD_recon.lua` | 1046 | recon section refresh |
| `CTLD_player.lua` | 602, 610 | flight-state poller (takeoff/land transitions), generic per-unit refresh |
| `CTLD_troop.lua` | 2100 | troop section refresh |
| `CTLD_vehicle.lua` | 1467, 1504, 1531, 1563, 1599 | vehicle load/unload/pack/parachute section refreshes |

For each site, determine:

- **Is it reached synchronously from inside the DCS command callback of the very group's own
  click** (embark, disembark, pack, unpack, request equipment confirm, etc.) — classify **urgent**.
- **Is it reached from `onTakeoff`/`onLand`** (a real, player-noticed state transition, not a
  silent background one) — classify **urgent**, per the PRD's decision.
- **Is it reached from a `timer.scheduleFunction` poll, a DCS world event not caused by this
  player's own action, or an `EventDispatcher` subscription fired by another player/object**
  (`OnFOBDeployed`, `OnCrateSpawned`, `OnCrateCleared`, `_lgzGroundPoll`, the hover-slingload
  1s poller, etc.) — leave **ambient** (the new default, no flag needed).

Deliver the classification as a table in this ticket's own "Findings" section below (edit this
file in place), one row per call site: file:line, the function it lives in, urgent/ambient, and a
one-line reason. Ticket 02 reads this table directly — do not just say "done", the table itself is
the deliverable.

## Watch out

- `menu:refresh()` on player-enter (`buildMenu`) never needs a flag either way — `_activeHandles`
  is empty on a brand-new menu, so there is nothing to race with.
- A call site invoked from inside another manager's `EventDispatcher` subscription is ambient by
  construction even if the event itself was caused by a player action — e.g.
  `CTLDCrateManager:_refreshNearbyPlayers` fans out to every nearby player when *any* crate spawns
  or clears, not just the one who spawned it. Classify from the *receiving* group's perspective,
  not the originating action's.
- Don't guess from the function name alone — read the actual call chain back to what triggered it
  (a menu command's own `wrapped` callback vs. a `timer.scheduleFunction`/event handler).

## Acceptance

- [ ] Every call site in the table above (plus any new one found by a fresh grep) has a
  recorded urgent/ambient classification with a one-line reason, in this file.
- [ ] No code change in `src/` — this ticket is audit-only.

## Findings

_(filled in during implementation of this ticket)_
