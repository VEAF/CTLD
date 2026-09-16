# 02 — Split ambient (delayed) vs urgent (immediate) menu refresh

**Status:** ⬜ ready

**Blocked by:** ticket 01 (confirms the small list of explicit-urgent call sites).

See the PRD and **ADR 0015** for the rationale, and ticket 01's "Design refinement" for why this
uses an automatic same-group-click detector instead of manually tagging ~30 call sites.

## What changes

`src/CTLD_menu.lua`:

1. New constant `AMBIENT_REBUILD_DELAY_S = 4` (module-level, same style as the existing
   `DEBOUNCE_S = 0.15`).
2. New field on the manager instance: `_activeCommandGroupId` (nil when no command callback is
   currently executing).
3. `_rebuildMenuNode`'s `wrapped` function ([:192](../../src/CTLD_menu.lua#L192)): set
   `ctld.MenuManager._activeCommandGroupId = groupId` immediately before `pcall(fn, arg)`, clear it
   (`= nil`) immediately after, regardless of whether `pcall` succeeded.
4. `ctld.Menu:refresh(opts)` — accepts an optional `opts` table (currently only supports
   `{ urgent = true }`), passes it straight through to `deferredRefreshForGroup`.
5. `ctld.MenuManager:deferredRefreshForGroup(groupId, opts)`:
   - Treat as **urgent** when `(opts and opts.urgent == true) or groupId ==
     ctld.MenuManager._activeCommandGroupId` — unchanged behavior: debounce at `DEBOUNCE_S` then
     `refreshMenuForGroup(groupId)` immediately.
   - Otherwise (**ambient**, the default): remove the group's root CTLD handle(s) **immediately**
     (same removal loop `refreshMenuForGroup` already does), then schedule the actual rebuild
     (`_rebuildMenuNode` over the sorted children + repopulating `_activeHandles`) via
     `timer.scheduleFunction` after `AMBIENT_REBUILD_DELAY_S` seconds.
   - Track a per-group pending-rebuild timer id/flag (a table keyed by `groupId`, like
     `_pendingRefresh` already is for the debounce — not a single shared flag, or one group's
     ambient refresh would block/cancel another group's).
   - A **second ambient** call for a group that already has a pending rebuild: coalesce — don't
     wipe again (nothing left to remove), don't reschedule the timer.
   - An **urgent** call for a group with a pending ambient rebuild: cancel the pending timer
     (`timer.removeFunction` with the stored function id — not just a boolean), run the full
     wipe+rebuild immediately (reuse `refreshMenuForGroup`, whose wipe is a no-op if nothing is
     left to remove), clear the pending state.
6. `refreshMenuForGroup(groupId)` itself is unchanged — the synchronous, non-debounced, full
   wipe+rebuild primitive both paths above call into.
7. Apply ticket 01's three explicit-urgent call sites (`onTakeoff`, `onLand`, the flight-state
   poller's TAKEOFF/LAND branches in `CTLD_player.lua`): change their `menu:refresh()` /
   `deferredRefreshForGroup(groupId)` calls to pass `{ urgent = true }`. Every other call site is
   untouched — the automatic same-group-click detector covers it.
8. `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- Don't touch `refreshMenuForGroup`'s own removal/rebuild logic — reuse it as the synchronous
  primitive for both the "urgent immediate" path and the "ambient, timer-delayed" path's actual
  rebuild step. Duplicating that logic risks the two paths drifting apart.
- `_activeCommandGroupId` must be cleared on **every** exit from `wrapped`, success or `pcall`
  failure — a `pcall` that returns `false` still needs the field reset, or a later ambient refresh
  for that same group gets wrongly treated as urgent until the next click for that group overwrites
  it (a latent bug, not a crash — but worth a comment explaining why the clear is unconditional).
- The pending-rebuild state must be **per groupId**, not a single shared flag/timer id.
- `timer.scheduleFunction`'s return value (function id) is what `timer.removeFunction` needs to
  cancel a pending rebuild when an urgent refresh preempts it — store it, don't just store a
  boolean.
- `buildMenu` on player-enter keeps calling `refresh()` with no special handling needed — an empty
  `_activeHandles` makes the "wipe" step a no-op either way, ambient or urgent.
- Re-entrancy: DCS/Lua callbacks don't preempt each other, so a single shared
  `_activeCommandGroupId` field (not per-group) is safe — only one command callback is ever
  executing at a time.

## Acceptance

- [ ] `menu:refresh()` called from **outside** any command callback (or for a different group than
  the one currently executing a command) wipes the group's CTLD root handle(s) immediately but
  does not re-add any command/submenu until `AMBIENT_REBUILD_DELAY_S` seconds later.
- [ ] `menu:refresh()` called **from inside** the currently-executing command callback's own group
  wipes and rebuilds in the same call — no observable behavior change from today for any existing
  click-triggered refresh (embark, disembark, pack, unpack, request equipment, etc.), including
  ones reached through a synchronous `EventDispatcher` publish nested in the same call stack.
- [ ] `menu:refresh({ urgent = true })` always wipes and rebuilds in the same call, regardless of
  context — used by `onTakeoff`/`onLand`/the flight-state poller.
- [ ] A second ambient refresh for the same group while one is already pending does not reset or
  duplicate the scheduled rebuild.
- [ ] An urgent refresh for a group with a pending ambient rebuild cancels the pending timer and
  rebuilds immediately — no double-rebuild, no leftover scheduled function firing later on stale
  state.
- [ ] A refresh fanned out to a *different* group than the one currently executing a command (e.g.
  `_refreshNearbyPlayers` reaching a bystander) stays ambient — proves the same-group check, not
  just "any command currently running", gates urgency.
- [ ] `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

Covered by ticket 03 (busted specs with a mocked timer, following the existing flight-state-poller
debounce test pattern already in `tests/ci/` for `CTLD_player.lua`'s poller). Not duplicated here
to keep implementation and verification as separate reviewable steps, per the PRD's own ticket
ordering.
