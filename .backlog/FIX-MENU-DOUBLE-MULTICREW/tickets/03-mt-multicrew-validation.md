Status: ready

# 03 — MT multi-crew manual test sequence + in-game validation

## Parent

`.backlog/FIX-MENU-DOUBLE-MULTICREW/PRD.md`

## What to build

Add an MT entry to `tests/manual_test_sequences.md` covering the multi-crew menu lifecycle.
The sequence must be replayed in a live DCS mission whenever `src/CTLD_menu.lua` or
`src/CTLD_player.lua` is modified.

The sequence covers three scenarios end-to-end:

1. **Menu doubling fix**: pilot enters CH-47, waits > 2 s, copilot joins the same slot — verify
   exactly one "CTLD" entry in F10 for both crew members, all items interactive.
2. **Non-last leave**: pilot leaves while copilot remains — verify copilot's "CTLD" menu is still
   present and interactive.
3. **Last leave teardown**: copilot leaves — verify "CTLD" entry is fully removed from F10 (no
   orphan entry).

The sequence also covers the single-pilot re-slot regression (user story 5): pilot leaves and
re-enters the same slot — verify exactly one "CTLD" entry, no duplication.

## Acceptance criteria

- [ ] MT entry added to `tests/manual_test_sequences.md` with perimeter, prerequisites, and
      step-by-step checklist (✅ / ❌ per step).
- [ ] All four scenarios (doubling, non-last leave, last-leave teardown, re-slot) are covered
      by the checklist.
- [ ] Sequence has been executed in a live DCS mission against the built `CTLD.lua` from
      ticket 02, with all steps ticked ✅ before merge.

## Blocked by

- `02-group-aware-leave-rebuild.md`
