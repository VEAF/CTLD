# 01 — Audit non-click-triggered "urgent" refresh entry points

**Status:** ✅ done

See the PRD and **ADR 0015**. This ticket's scope was narrowed during implementation — see
"Design refinement" below before reading the rest.

## Design refinement (supersedes the original per-call-site classification)

The original plan was to manually tag each of the ~30 `menu:refresh()` call sites as `urgent` or
`ambient`. Mapping the actual call graph
(`refreshUnpackSection`, `refreshRequestEquipmentSection`, `refreshLoadCrateSection`,
`refreshPackEquiptSection`, `refreshCrateFlightSection`, `refreshMenuSection` (troop),
`refreshLoadSection`/`refreshUnloadSection`/`refreshParachuteVehicleSection` (vehicle),
`refreshJtacEquipmentSection`) showed these are **shared functions**, each called from both a
direct player-click context and a background/cross-player context (e.g.
`CTLDCrateManager:_refreshNearbyPlayers` fans the same function out to every nearby player, not
just the one whose action triggered it). Tagging correctly would mean threading an `opts`
parameter through dozens of signatures across 6 files.

**Simpler mechanism, same observable behavior**: DCS/Lua has no preemption — one menu command's
callback (`ctld.MenuManager:_rebuildMenuNode`'s `wrapped` function,
[CTLD_menu.lua:192](../../src/CTLD_menu.lua#L192)) runs synchronously to completion before another
can start. So "is this refresh a direct, synchronous consequence of group G's own action" can be
answered by a single shared field set for the duration of that action — no parameter threading:

- A new `ctld.MenuManager:runUrgent(groupId, fn)` helper sets `_urgentGroupId = groupId`, runs
  `fn()`, clears `_urgentGroupId` unconditionally afterward (success or error).
- `wrapped` routes its existing `pcall(fn, arg)` through `runUrgent(groupId, ...)`.
- `deferredRefreshForGroup(groupId, opts)` treats the refresh as urgent when
  `opts and opts.urgent == true` **or** `groupId == ctld.MenuManager._urgentGroupId`.

This makes every refresh reached synchronously from a group's own click urgent **automatically**,
with zero changes at ~25 of the ~30 original call sites — including ones nested behind an
`EventDispatcher` publish that fires synchronously within the same call stack (`OnCrateLoaded`,
`OnVehicleLoaded`, etc.), since Lua's synchronous event dispatch means the flag is still set when
those handlers run. Critically, it also gets bystanders right for free: `_refreshNearbyPlayers`
fanning out to a *different* group mid-callback compares that group's id against `_urgentGroupId`
(the acting group's id) and correctly finds no match → stays ambient — the exact "classify from
the receiving group's perspective" rule the original ticket called for, without having to enforce
it by hand at each fan-out site.

The same `runUrgent` helper is reused (not the `{ urgent = true }` opts flag) for the three
no-click-context sites below — they wrap their existing refresh calls in
`runUrgent(playerObj.groupId, function() ... end)` too, since it's the identical mechanism applied
from a non-click context rather than a separate code path.

## What changes

No behavior change in this ticket — it identifies the (small) remaining set of refreshes that have
**no click context at all** to automatically detect, and therefore still need an explicit
`{ urgent = true }` opt-in per the PRD's decision ("a real, player-noticed state transition, not a
silent background one").

Confirmed candidates (verify with a fresh read before ticket 02 implements — this is a starting
point):

| Site | Why it needs `runUrgent` wrapping |
|---|---|
| `CTLDPlayerManager:onTakeoff` ([CTLD_player.lua:434](../../src/CTLD_player.lua#L434)) | Fired from `S_EVENT_TAKEOFF`, not a menu click — no command-callback context exists to auto-detect. |
| `CTLDPlayerManager:onLand` ([CTLD_player.lua:394](../../src/CTLD_player.lua#L394)) | Same — `S_EVENT_LAND`, no click context. |
| The flight-state poller's TAKEOFF/LAND branches ([CTLD_player.lua:202-265](../../src/CTLD_player.lua#L202), inside `timer.scheduleFunction`) | Same real transition as takeoff/land, detected redundantly by polling — no click context either. |

Everything else (crate load/unpack/pack, troop embark/disembark, vehicle load/unload/pack,
JTAC equipment refresh, recon refresh, and every `EventDispatcher`-mediated cascade reached
synchronously from one of those) needs **no change** — the automatic mechanism covers it.

## Watch out

- Don't hunt for more explicit-urgent candidates among the pollers/events that are genuinely
  background (`_lgzGroundPoll`, the hover-slingload poller, `_checkNativeDCSCargo`, `onCrateDead`,
  `OnFOBDeployed`/`OnCrateSpawned`/`OnCrateCleared` fan-outs to bystanders) — those are correctly
  ambient by the new default and the PRD doesn't ask for them to be urgent.
- `buildMenu` on player-enter needs no flag either way — `_activeHandles` is empty on a brand-new
  menu, nothing to race with, urgent or not.
- Confirm `_activeCommandGroupId` truly gets cleared on every exit path from `wrapped`, including
  when `fn` errors inside `pcall` — a leftover stale value would wrongly mark a later, unrelated
  ambient refresh for that same group as urgent until the next click overwrites it.

## Acceptance

- [x] The three sites above (or whatever a fresh grep confirms as the complete "real transition,
  no click context" set) are the only call sites carrying an explicit `{ urgent = true }`.
- [x] No code change in `src/` — this ticket is audit-only; ticket 02 implements both the
  automatic mechanism and these explicit opt-ins.

## Findings

Confirmed via fresh read of `CTLD_player.lua` (2026-09-16): the three sites listed above are the
complete set. No other call site in `src/` reaches a menu refresh without either (a) a live
command-callback context on the same group, or (b) being an intentionally-ambient
poll/cross-player event.
