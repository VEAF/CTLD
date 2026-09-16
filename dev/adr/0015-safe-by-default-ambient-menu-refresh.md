# ADR 0015 — Safe-by-default delay on ambient F10 menu refreshes

**Date:** 2026-09-16
**Status:** Accepted
**Lot:** FIX-MENU-AMBIENT-REFRESH-RACE (to be formalized via `to-prd`)

## Context

Reported live: a C-130 parked on a TRZ requested "Load Standard Group" from `Troop Commands >
Embark / Extract Troops`, and instead triggered `Smoke > Red` at the aircraft's position.
Reproduced twice against the live mission via `dcs-serve`/`exec_lua`:

1. Forcing `ctld.MenuManager:refreshMenuForGroup(groupId)` while a player was navigated into
   `Load from <TRZ>` caused the very next click (4.2 s later) to fire `CTLDCrateManager:dropSmoke`
   instead of `CTLDTroopManager:embarkFromTroopZone` — confirming a genuine DCS client/server
   desync, not a menu-reordering illusion (the troop menu path for an empty transport has no
   conditional sibling that could have shifted F-key numbers).
2. Splitting the same rebuild into "remove all root handles now" + "re-add after an explicit 8 s
   delay" and clicking mid-gap produced **no CTLD action at all** (confirmed via `dcs.log`: zero
   command log lines between the wipe and the rebuild) — the player's screen just showed the CTLD
   menu gone, then it reappeared.

Root cause: `ctld.MenuManager:refreshMenuForGroup` ([CTLD_menu.lua](../../src/CTLD_menu.lua))
wipes and rebuilds ALL of a group's CTLD menu atomically on every call — by design (see
`docs/developer/subsystems/menu.md`, "atomic, all-or-nothing rebuilds"), not a bug. The existing
`DEBOUNCE_S = 0.15` in `deferredRefreshForGroup` only coalesces rapid-fire bursts; it does nothing
about a single, legitimate refresh landing while the player is mid-navigation. The most common
trigger for this in gameplay is exactly the worst case: `_lgzGroundPoll`
([CTLD_crate.lua:295-325](../../src/CTLD_crate.lua)), a 10 s background poll that rebuilds the
whole menu the moment a grounded unit's logistic-zone membership changes — i.e. almost exactly
when a transport has just parked at a pickup zone and the pilot is most likely opening F10 for the
first time.

DCS exposes no API or event indicating whether a player's F10 menu is currently open, nor at what
depth — verified against the `missionCommands`/`world.event` surface CTLD already uses; no such
hook exists. **Partial/targeted submenu removal** (only touch the branch that actually changed)
was also considered and rejected: it is exactly what the legacy monolith did
(`migration/source/CTLD.lua`'s `ctld.updatePackMenu`, `missionCommands.removeItemForGroup(groupId,
PackCommandsPath)`), and the rewrite deliberately replaced it with the current atomic wipe+rebuild
model for consistency — reintroducing partial rebuilds was explicitly ruled out when scoping this
fix.

## Decision

Any menu refresh not tied to the group's own immediately-preceding action is **ambient** and gets
a new, safe-by-default behavior: remove the group's root CTLD handle **immediately** (as today),
then delay the rebuild by a new fixed constant (`AMBIENT_REBUILD_DELAY_S = 4`, same style as the
existing `DEBOUNCE_S`) instead of rebuilding in the same tick. A click landing in that window now
resolves to nothing instead of a wrong command.

Call sites that are a **direct, synchronous consequence of the very group's own action** — the
refresh a menu command triggers right after completing (embark/disembark/pack/unpack), and
`onTakeoff`/`onLand` — opt out via an explicit `urgent = true` flag and keep today's immediate
behavior: the player just interacted, so there is no stale-screen risk to guard against, and
delaying would only add gratuitous latency.

**Default is safe, not immediate**: any new background trigger written in the future (a poller, an
event fan-out to nearby/all players) inherits the delayed, safe behavior automatically unless it
explicitly opts into `urgent = true` — an omission costs a several-second visual blank, never a
wrong action.

If an `urgent` refresh arrives for a group while an ambient delay is already pending, the pending
timer is cancelled and the rebuild happens immediately — the wipe already happened, so there is
nothing left to protect by waiting out the rest of the window.

**Urgency is detected automatically for click-triggered refreshes, not tagged by hand at each call
site.** Mapping the actual call graph found ~30 `menu:refresh()` sites funnelling through a
handful of shared functions (`refreshUnpackSection`, `refreshRequestEquipmentSection`, etc.), each
reachable from *both* a direct player click and a background/cross-player context (e.g.
`_refreshNearbyPlayers` fans the same function out to every nearby player, not just the actor) —
tagging correctly would mean threading an `opts` parameter through dozens of signatures. Instead,
since DCS/Lua callbacks never preempt each other, the menu command dispatcher
(`_rebuildMenuNode`'s `wrapped` function) records the acting group's id in a single shared field
(`_activeCommandGroupId`) for the duration of that one callback, clearing it unconditionally
afterward. `deferredRefreshForGroup(groupId, opts)` treats a refresh as urgent when
`groupId == _activeCommandGroupId` — true for any refresh reached synchronously from that click,
however many layers of shared function or synchronous `EventDispatcher` publish deep — **and false
for a fan-out to a different group's menu mid-callback**, which is exactly the "classify from the
receiving group's perspective" rule this ADR needs, achieved without enforcing it by hand at every
fan-out site. Only refreshes with *no* click context at all — `onTakeoff`, `onLand`, and the
flight-state poller's takeoff/land branches, none of them reached from inside a menu command — still
need the explicit `urgent = true` opt-in.

## Considered options

- **Partial/targeted submenu reconstruction** (only rebuild the changed branch). Rejected: this is
  what legacy did and what the `src/` rewrite deliberately abandoned for atomicity; reintroducing
  it recreates the exact inconsistency risk the current design exists to avoid.
- **Detect when the player's menu is open/at what depth.** Rejected: no such DCS API or event
  exists; verified against the full `missionCommands`/`world.event` surface already used by CTLD.
- **Explicit opt-in only** (leave the default immediate, tag only the 1-2 known dangerous call
  sites — `_lgzGroundPoll`, `OnFOBDeployed`, `OnCrateSpawned`/`OnCrateCleared` — as ambient).
  Rejected: a future background refresh trigger would silently inherit the dangerous immediate
  default if its author forgot to mark it ambient — the bug class would still be one careless
  `timer.scheduleFunction` away from recurring.
- **Reduce `_lgzGroundPoll`'s frequency instead of gating on timing.** Rejected as insufficient
  alone: it lowers how often the race *can* occur but does not address the general mechanism, and
  the worst-case timing (right after parking at a pickup zone) is inherent to what the poll is
  for, not to its frequency.

## Consequences

- Any ambient refresh (most background pollers and cross-player event fan-outs) makes a player's
  CTLD F10 menu visibly disappear for up to ~4 s if they happen to be looking at that exact moment
  — a new, deliberate, minor visual glitch traded for eliminating wrong-action misfires. Not
  eliminated in every theoretical case (DCS's own client-side staleness window is not scripted and
  could in principle outlast 4 s under heavy simulation lag — `ANTIFREEZE ENABLED` warnings were
  observed in the reproduction session's `dcs.log`), but sharply reduced from the observed 4-16 s
  window down to whatever residual gap exceeds the constant.
- Only the handful of no-click-context "real transition" call sites (`onTakeoff`, `onLand`, the
  flight-state poller) need explicit `urgent = true`; everything else is covered automatically by
  the same-group-click detector. A future refresh added inside a menu command's own callback needs
  no tagging at all — it inherits urgency for free. A future *background* trigger that should
  somehow be urgent (unlikely, but possible) would need the explicit flag; forgetting it costs an
  unnecessary ~4 s lag, not a correctness bug.
