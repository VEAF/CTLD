# 01 — Log "no group found" at DEBUG in `CTLDTroopManager:onUnitDead`

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

In `CTLDTroopManager:onUnitDead` (`src/CTLD_troop.lua`), change the `ctld.utils.log` call of the
`no group found for unit '%s' — skipping` branch from `"INFO"` to `"DEBUG"`. Nothing else.

## Acceptance

- A death of a unit belonging to no CTLD group emits no `INFO` log line (a `DEBUG` one is emitted)
  and the handler returns without error.
- A death of a unit in a CTLD group still emits the `INFO` `removed from group` line and cleans up
  as before.
- `CHANGELOG.md` `[Unreleased]` has a `Fixed` entry referencing issue #212.

## Tests (TDD — write first)

In `tests/ci/functional/troop_manager_spec.lua`, `describe("F-037 — onUnitDead", ...)`: stub
`ctld.utils.log` (restore in `after_each`, pattern from `tests/ci/unit/static_watcher_spec.lua`),
add (1) unknown unit → no `INFO`, one `DEBUG`; (2) registered troop → `INFO` `removed from group`
still logged.

## Then

Rebuild `CTLD.lua`, run `busted tests/ci/` and luacheck, set the `.backlog/README.md` index line to
`merged (PR #NN)` in the delivering PR.
