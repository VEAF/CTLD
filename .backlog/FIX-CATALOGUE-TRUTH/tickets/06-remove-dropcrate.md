# 06 — remove `dropCrate` and `maxDropHeight`

**Status:** ready

Closes `dev/roadmap.md` item 4. **The only ticket in this lot that touches `src/`.**

## Why

`CTLDCrateManager:dropCrate` ([CTLD_crate.lua:2127](../../../src/CTLD_crate.lua#L2127)) has no caller
in `src/`, is not exposed through `src/legacy/legacy_api.lua`, and does not exist in the legacy
monolith at all — neither `dropCrate` nor `maxDropHeight` appears there. It was introduced during the
modernisation (`migration/MODERNIZATION-PLAN.md` lists `maxDropHeight` among the planned defaults) and
never wired.

It was **not** groundwork for the parachute feature — it is what the parachute feature replaced. The
airborne drop is fully implemented by `parachuteCrates` ([:2290](../../../src/CTLD_crate.lua#L2290)),
reached from the flight-state-aware F10 menu ([:905-914](../../../src/CTLD_crate.lua#L905),
[:2981](../../../src/CTLD_crate.lua#L2981)), with a configured descent rate, intact landing and
auto-unpack, plus a `CTLDParachuteEffect` extension point for plugins. The menu offers `unloadCrate`
on the ground and `parachuteCrates` in the air; there is no third state for `dropCrate` to serve, and
`parachuteCrates` handles a 3 m hover as well as a high drop.

## What changes

- `src/CTLD_crate.lua`: delete `dropCrate` and its doc comment.
- `src/CTLD_config.yaml`: delete `maxDropHeight`.
- `src/CTLD_config_schema.yaml`: delete the `maxDropHeight` entry.
- `docs/developer/events.md` and `events.fr.md`: remove `:dropCrate()` from the **Published by** lines
  of `OnCrateUnloaded` and `OnCrateDestroyed` (4 lines total, 2 per language).
- `tests/ci/unit/crate_lifecycle_spec.lua`: remove the F-031 / F-032 cases and the `dropCrate` part of
  the F-029 describe block. Leave `unloadCrate` coverage intact.
- Rebuild `CTLD.lua`; the parity oracle regenerates.
- `dev/roadmap.md`: delete entry 4.

## Watch the coverage ratchet

F-031 / F-032 exist because `REINTEGRATE-ORPHAN-TESTS` deliberately rebuilt coverage for them from
FullGas's dead relics. Removing tested code removes both covered and total lines, so the ratio can move
either way. Check the gate before pushing; if it dips, the fix is more coverage elsewhere in this lot,
never lowering the floor.

## Acceptance

- `grep -rn "dropCrate\|maxDropHeight" src/ docs/ tests/` returns nothing except the unrelated
  `RandomReal("dropCrates", …)` calls.
- `unloadCrate`, `parachuteCrates` and `cutSlingload` are untouched and still tested.
- `CHANGELOG.md` `[Unreleased]` records the removal of an unreachable method and its setting, so a
  reader of an older config understands why `maxDropHeight` now reports as dropped by `version-gap`.
- Coverage gate passes.
