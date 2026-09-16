# FIX-MENU-AMBIENT-REFRESH-RACE — a background F10 menu rebuild can fire the wrong CTLD command

**Status:** 🔄 in-progress

Reported live by **a.lingo**, 2026-09-16: a C-130 parked on a TRZ requested "Load Standard Group"
from `Troop Commands > Embark / Extract Troops`, and instead triggered `Smoke > Red` at the
aircraft's position. Grilled with docs the same day (**ADR 0015**).

## The deviation

`ctld.MenuManager:refreshMenuForGroup` ([CTLD_menu.lua:112](../../src/CTLD_menu.lua#L112)) wipes
and rebuilds **all** of a group's CTLD F10 menu atomically on every call — by design, documented in
`docs/developer/subsystems/menu.md` as "atomic, all-or-nothing rebuilds", not a regression. The
existing `DEBOUNCE_S = 0.15` in `deferredRefreshForGroup` only coalesces rapid-fire bursts within
the same instant; it does nothing when a single, legitimate refresh lands while a player is
mid-navigation in the menu it just tore down and rebuilt.

The most common real trigger for this is close to the worst possible timing: `_lgzGroundPoll`
([CTLD_crate.lua:295-325](../../src/CTLD_crate.lua#L295)), a 10 s background poll that rebuilds a
grounded unit's whole menu the moment its logistic-zone membership changes — i.e. almost exactly
when a transport has just parked at a pickup zone, the moment a pilot is most likely opening F10
for the first time. `OnFOBDeployed`, `OnCrateSpawned` and `OnCrateCleared`
([CTLD_crate.lua:170-180, 285-290](../../src/CTLD_crate.lua#L170)) fan the same kind of
unsolicited, no-player-action rebuild out to every nearby/grounded player, independent of what
they're doing with their own menu.

**Reproduced live twice** against the actual mission (via `dcs-serve`/`exec_lua`, 2026-09-16):

1. Forcing `refreshMenuForGroup` while a player was navigated into `Load from <TRZ>` (the "Load
   Standard Group" list) caused the very next click — **4.2 s later** — to fire
   `CTLDCrateManager:dropSmoke` instead of `CTLDTroopManager:embarkFromTroopZone`
   (`dcs.log`-timestamped). The troop menu path for an empty transport has no conditional sibling
   that could reorder F-keys between builds, ruling out "the menu shape shifted and the player used
   a stale shortcut" — this is a genuine DCS client/server desync during the rebuild, not a
   reordering artefact.
2. Splitting the same rebuild into "remove all root handles now" then "re-add after an explicit 8 s
   delay", and clicking mid-gap, produced **no CTLD action at all** — zero CTLD command log lines
   between the wipe and the rebuild. The player's F10 just showed the CTLD menu gone, then it
   reappeared.

DCS exposes no API or event indicating whether a player's F10 menu is open, nor at what depth —
checked against the full `missionCommands`/`world.event` surface CTLD already uses. **Partial,
targeted submenu removal** (touch only the branch that changed, the way
`migration/source/CTLD.lua`'s `ctld.updatePackMenu` does with
`missionCommands.removeItemForGroup(groupId, PackCommandsPath)`) was considered and rejected: the
`src/` rewrite already deliberately replaced that model with the current atomic wipe+rebuild for
consistency, before this lot — reintroducing it would undo that decision to work around a
different bug. Full alternatives record: **ADR 0015**.

## The fix

Any menu refresh that is not the direct, synchronous consequence of the group's own just-completed
action is **ambient**, and becomes safe by default: remove the group's root CTLD handle
immediately (as today), then delay the actual rebuild by a new fixed constant
(`AMBIENT_REBUILD_DELAY_S = 4`, same style as the existing `DEBOUNCE_S`) instead of rebuilding in
the same tick. A click landing in that window now resolves to nothing instead of a wrong command.

Call sites that are a direct consequence of the player's own immediately-preceding action — the
refresh that follows a successful embark/disembark/pack/unpack inside its own command handler, and
`onTakeoff`/`onLand` — opt out via an explicit `urgent = true` flag on the refresh call and keep
today's immediate rebuild: the player just interacted, so there is no stale-screen risk to guard
against, and delaying would only add gratuitous latency.

**Default is safe, not immediate.** A future background trigger (another poller, another
cross-player event fan-out) inherits the delayed, safe behavior automatically unless it explicitly
opts into `urgent = true` — an omission costs a few seconds of visual blank, never a wrong action.

If an `urgent` refresh arrives for a group while an ambient delay is already pending, the pending
timer is cancelled and the rebuild happens immediately — the wipe already happened, so there is
nothing left to protect by waiting out the rest of the window.

Legacy parity: not applicable as a constraint here. Legacy's analogous mechanism used partial,
per-path removal, not a single-root atomic wipe — the `src/` rewrite already diverged from it
before this lot, by deliberate design, not by omission.

## Definition of done

- `deferredRefreshForGroup`/`refreshMenuForGroup` in `CTLD_menu.lua` default to the ambient
  behavior (immediate wipe, rebuild delayed `AMBIENT_REBUILD_DELAY_S` seconds later) unless called
  with `urgent = true`.
- An `urgent` refresh arriving while an ambient delay is pending for the same group cancels the
  pending timer and rebuilds immediately.
- Every existing call site in `src/` that refreshes a menu as the direct result of the acting
  player's own command (embark, disembark, pack, unpack, `onTakeoff`, `onLand`, and any other
  refresh invoked from inside a menu command's own callback) is audited and explicitly passes
  `urgent = true`.
- Every other existing call site (background pollers, cross-player event fan-outs such as
  `OnFOBDeployed`/`OnCrateSpawned`/`OnCrateCleared`) is confirmed to use the new ambient default —
  no explicit change needed there beyond verifying none of them were accidentally passing an
  equivalent "immediate" flag.
- A busted spec (mocked timer, following the existing flight-state-poller debounce test pattern)
  proves: (a) an ambient refresh wipes immediately but does not re-add commands until the delay
  elapses, (b) a click simulated inside that window finds no CTLD command, (c) an urgent refresh
  arriving mid-delay cancels the wait and rebuilds immediately.
- A live `dcs-bridge` scenario (`ia`-tier, human-driven) re-runs this PRD's own reproduction steps
  (navigate into `Load from <TRZ>`, force an ambient refresh, click) and confirms the misfire no
  longer occurs — either nothing fires during the delay, or the correct command fires once the
  menu is current again.
- `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean.
- `CHANGELOG.md` **Fixed** entry.

## Out of scope

- Reducing `_lgzGroundPoll`'s 10 s cadence, or any other poller's frequency. Rejected in ADR 0015
  as insufficient alone — it lowers how often the race can occur without addressing the mechanism,
  and the worst-case timing (right after parking at a pickup zone) is inherent to what the poll
  exists to detect.
- Any form of partial/targeted submenu reconstruction. Explicitly rejected in ADR 0015 — it is what
  legacy did and what the rewrite deliberately replaced.
- Detecting whether a player's F10 menu is open or at what depth. No such DCS API or event exists;
  not revisitable without an engine-level capability CTLD does not have.
- Making `AMBIENT_REBUILD_DELAY_S` a mission-maker-configurable setting. It is an internal timing
  constant, not a gameplay parameter — kept as a fixed Lua constant, no `ctld.gs()` catalogue entry,
  no schema/i18n/webapp surface.
- A 100% guarantee against the misfire. DCS's own client-side staleness window is not scripted and
  is not bounded by this fix's constant under heavy simulation lag (the reproduction session's
  `dcs.log` showed `ModelTimeQuantizer: ANTIFREEZE ENABLED` warnings) — this lot sharply reduces
  the danger window (observed 4-16 s down to whatever residual gap exceeds 4 s), it does not close
  it to zero.

## Further Notes

- Full trade-off record and rejected alternatives: **ADR 0015**
  (`dev/adr/0015-safe-by-default-ambient-menu-refresh.md`).
- The audit of call sites (urgent vs ambient-by-default) should happen as its own ticket, before
  the `CTLD_menu.lua` implementation ticket — enumerating what exists today is cheap and avoids
  re-discovering call sites mid-implementation.
- No CONTEXT.md change: "ambient" / "urgent" are menu-subsystem implementation vocabulary, not
  domain/gameplay terms — they belong in `docs/developer/subsystems/menu.md`, not the domain
  glossary.
