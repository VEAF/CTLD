# 02 — Split ambient (delayed) vs urgent (immediate) menu refresh

**Status:** ⬜ ready

**Blocked by:** ticket 01 (needs its classification table to tag call sites correctly).

See the PRD and **ADR 0015** for the full rationale and the two live reproductions this fixes.

## What changes

`src/CTLD_menu.lua`:

1. New constant `AMBIENT_REBUILD_DELAY_S = 4` (module-level, same style as the existing
   `DEBOUNCE_S = 0.15`).
2. `ctld.Menu:refresh(opts)` — accepts an optional `opts` table (currently only
   `{ urgent = true }`), passes it straight through to `deferredRefreshForGroup`.
3. `ctld.MenuManager:deferredRefreshForGroup(groupId, opts)`:
   - `opts.urgent == true`: unchanged behavior — debounce at `DEBOUNCE_S` then
     `refreshMenuForGroup(groupId)` immediately, exactly as today.
   - Otherwise (ambient, the default): remove the group's root CTLD handle(s) **immediately**
     (same removal loop `refreshMenuForGroup` already does), then schedule the actual rebuild
     (`_rebuildMenuNode` over the sorted children + repopulating `_activeHandles`) via
     `timer.scheduleFunction` after `AMBIENT_REBUILD_DELAY_S` seconds.
   - Track a per-group pending-rebuild timer id/flag. If a **second** ambient call arrives for the
     same group while a rebuild is already pending (wipe already done, waiting to rebuild),
     coalesce: don't wipe again (nothing left to remove), don't reschedule the timer — let the
     already-scheduled rebuild run once.
   - If an **urgent** call arrives for a group while an ambient rebuild is pending: cancel the
     pending timer, run the full wipe+rebuild immediately (reuse `refreshMenuForGroup` as-is — the
     wipe is a no-op if nothing is left to remove, which is fine), and clear the pending state.
4. `refreshMenuForGroup(groupId)` itself is unchanged — it remains the synchronous, non-debounced,
   full wipe+rebuild primitive both paths above call into.
5. Apply ticket 01's classification: every call site it marked **urgent** passes
   `{ urgent = true }` through `menu:refresh({ urgent = true })`; every call site marked
   **ambient** calls `menu:refresh()` unchanged (new default takes over automatically — no
   per-site code needed there beyond leaving it alone).
6. `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- Don't touch `refreshMenuForGroup`'s own removal/rebuild logic — reuse it as the synchronous
  primitive for both the "urgent immediate" path and the "ambient, timer-delayed" path's actual
  rebuild step. Duplicating that logic risks the two paths drifting apart.
- The pending-rebuild state must be **per groupId** (a table keyed by groupId, like
  `_pendingRefresh` already is for the debounce) — not a single shared flag, or one group's ambient
  refresh would block/cancel another group's.
- `timer.scheduleFunction`'s return value (function id) is what `timer.removeFunction` needs to
  cancel a pending rebuild when an urgent refresh preempts it — store it, don't just store a
  boolean.
- Buildmenu on player-enter (`buildMenu`) must keep calling `refresh()` with no special handling
  needed — an empty `_activeHandles` makes the "wipe" step a no-op either way, ambient or urgent.

## Acceptance

- [ ] `menu:refresh()` (no opts) wipes the group's CTLD root handle(s) immediately but does not
  re-add any command/submenu until `AMBIENT_REBUILD_DELAY_S` seconds later.
- [ ] `menu:refresh({ urgent = true })` wipes and rebuilds in the same call, exactly as
  `refreshMenuForGroup` does today (no observable behavior change for urgent call sites).
- [ ] A second ambient refresh for the same group while one is already pending does not reset or
  duplicate the scheduled rebuild.
- [ ] An urgent refresh for a group with a pending ambient rebuild cancels the pending timer and
  rebuilds immediately — no double-rebuild, no leftover scheduled function firing later on stale
  state.
- [ ] Every call site from ticket 01's table carries the correct flag.
- [ ] `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

Covered by ticket 03 (busted specs with a mocked timer, following the existing flight-state-poller
debounce test pattern already in `tests/ci/` for `CTLD_player.lua`'s poller). Not duplicated here
to keep implementation and verification as separate reviewable steps, per the PRD's own ticket
ordering.
