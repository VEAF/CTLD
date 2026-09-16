# 02 — Split ambient (delayed) vs urgent (immediate) menu refresh

**Status:** ✅ done

**Blocked by:** ticket 01 (confirms the small list of no-click-context urgent sites).

See the PRD and **ADR 0015** for the rationale, and ticket 01's "Design refinement" for why this
uses an automatic same-group detector instead of manually tagging ~30 call sites.

## What changes

`src/CTLD_menu.lua`:

1. New constants `AMBIENT_REBUILD_DELAY_S = 4` and (unchanged) `DEBOUNCE_S = 0.15`.
2. New field on the manager instance: `_urgentGroupId` (nil when no group's refreshes are
   currently forced urgent) and `_pendingAmbient` (per-group pending-ambient-rebuild state,
   alongside the existing `_pendingRefresh`).
3. New method `ctld.MenuManager:runUrgent(groupId, fn)`: sets `_urgentGroupId = groupId`, calls
   `fn()` inside `pcall`, clears `_urgentGroupId` unconditionally, re-raises `fn`'s error after
   cleanup (never swallows it — callers needing resilience wrap `fn` in their own `pcall` first).
4. `_rebuildMenuNode`'s `wrapped` function: route the existing `pcall(fn, arg)` through
   `runUrgent(groupId, ...)` instead of calling it directly — every menu click now auto-marks its
   own group urgent for the duration of the callback, with the same crash-isolating behavior as
   today (the inner `pcall` result is still captured and logged exactly as before).
5. `ctld.Menu:refresh(opts)` — accepts an optional `opts` table (currently only supports
   `{ urgent = true }`) as a direct escape hatch alongside the automatic detector, passed straight
   through to `deferredRefreshForGroup`.
6. `ctld.MenuManager:deferredRefreshForGroup(groupId, opts)`:
   - Treat as **urgent** when `(opts and opts.urgent == true) or groupId ==
     ctld.MenuManager._urgentGroupId` — unchanged behavior: debounce at `DEBOUNCE_S` then
     `refreshMenuForGroup(groupId)`.
   - Otherwise (**ambient**, the default): wipe the group's root CTLD handle(s) **immediately**
     (via the new shared `_wipeGroupHandles` helper, factored out of `refreshMenuForGroup`), then
     schedule the actual rebuild (`refreshMenuForGroup` again — its own wipe becomes a no-op since
     nothing is left to remove) via `timer.scheduleFunction` after `AMBIENT_REBUILD_DELAY_S`
     seconds.
   - Track pending-ambient state **per groupId** (`_pendingAmbient[groupId] = { timerId }`) — a
     second ambient call for a group that already has one pending coalesces (no re-wipe, no
     reschedule).
   - An **urgent** call for a group with a pending ambient rebuild: `timer.removeFunction` the
     stored timer id, clear the pending state, then proceed through the normal urgent
     (debounced-immediate) path — the wipe already happened, nothing left to protect by waiting.
7. `refreshMenuForGroup(groupId)` itself keeps its exact observable behavior (same log lines, same
   order of operations) — only its wipe step is now the shared `_wipeGroupHandles` helper instead
   of an inlined loop, so both paths call the identical removal code.
8. Apply ticket 01's three no-click-context sites in `CTLD_player.lua` — `onTakeoff`, `onLand`, and
   the flight-state poller's TAKEOFF/LAND branches: wrap their existing refresh-calling bodies in
   `ctld.MenuManager:getInstance():runUrgent(playerObj.groupId, function() ... end)`. These do
   **not** use the `{ urgent = true }` opts flag — `runUrgent` is the same automatic mechanism menu
   clicks use, just invoked from a non-click context (a real state transition with no command
   callback to point at). Every other call site is untouched.
9. `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- Don't touch `refreshMenuForGroup`'s own rebuild logic — only its wipe step moves into
  `_wipeGroupHandles`, reused by the ambient path. Duplicating the wipe loop risks the two paths
  drifting apart.
- `_urgentGroupId` must be cleared on **every** exit from `runUrgent`, success or error — this is
  why `runUrgent` uses its own unconditional `pcall`+clear+re-raise rather than trusting each
  caller to remember cleanup.
- The pending-ambient state must be **per groupId**, not a single shared flag/timer id.
- `timer.scheduleFunction`'s return value (function id) is what `timer.removeFunction` needs — a
  pending-ambient entry must store the id, not just a boolean.
- `buildMenu` on player-enter keeps calling `refresh()` with no special handling needed — an empty
  `_activeHandles` makes the wipe step a no-op either way, ambient or urgent.
- Re-entrancy: DCS/Lua callbacks don't preempt each other, so a single shared `_urgentGroupId`
  field (not per-group) is safe — only one command callback (or `runUrgent` call) is ever
  executing at a time.

## Acceptance

- [x] `menu:refresh()` called from **outside** any `runUrgent` context (or for a different group
  than the one currently inside one) wipes the group's CTLD root handle(s) immediately but does
  not re-add any command/submenu until `AMBIENT_REBUILD_DELAY_S` seconds later.
- [x] `menu:refresh()` called **from inside** `runUrgent(G, ...)` for that same group `G` wipes and
  rebuilds in the same call — no observable behavior change from today for any existing
  click-triggered refresh (embark, disembark, pack, unpack, request equipment, etc.), including
  ones reached through a synchronous `EventDispatcher` publish nested in the same call stack.
- [x] `menu:refresh({ urgent = true })` always wipes and rebuilds in the same call, regardless of
  `_urgentGroupId` — the direct escape hatch works independently of the automatic detector.
- [x] `onTakeoff`, `onLand`, and the flight-state poller's TAKEOFF/LAND transitions rebuild
  immediately (via `runUrgent`), matching today's behavior exactly.
- [x] A second ambient refresh for the same group while one is already pending does not reset or
  duplicate the scheduled rebuild.
- [x] An urgent refresh for a group with a pending ambient rebuild cancels the pending timer and
  rebuilds immediately — no double-rebuild, no leftover scheduled function firing later on stale
  state.
- [x] A refresh fanned out to a *different* group than the one currently inside a `runUrgent` call
  (e.g. `_refreshNearbyPlayers` reaching a bystander) stays ambient — proves the same-group check,
  not just "some urgent context is active", gates urgency.
- [x] `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

Covered by ticket 03 (busted specs with a mocked timer, following the existing flight-state-poller
debounce test pattern already in `tests/ci/` for `CTLD_player.lua`'s poller). Not duplicated here
to keep implementation and verification as separate reviewable steps, per the PRD's own ticket
ordering.
