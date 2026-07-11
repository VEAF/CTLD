# 01 — Crate lifecycle manager methods + events (PILOT)

Status: 🚧 in progress
Type: AFK

## What to build

`tests/ci/unit/crate_lifecycle_spec.lua` — busted coverage for the `CTLDCrateManager` *manager*
methods and their event contracts (the existing `crate_manager_spec.lua` covers only the
entity-level `crate:load/unload/unpack` transitions and `getCrateByName`/`getCratesInRange`).

Re-integrates relics:
- F-027 `registerMMCrate` — register mission-maker crate + guards (duplicate, unknown type)
- F-028 `loadCrate` — → LOADED, publishes `OnCrateLoaded`, guards (unknown, not-on-ground)
- F-029 `unloadCrate` — → LANDED, publishes `OnCrateUnloaded` (method) + `OnCrateSpawned`
- F-030 `unpackCrate` — → UNPACKED, publishes `OnCrateUnpacked`, unregisters
- F-031 `dropCrate` ≤ maxDropHeight — → LANDED, publishes `OnCrateUnloaded` (method="drop")
- F-032 `dropCrate` > maxDropHeight — destroyed, publishes `OnCrateDestroyed` (reason="drop_impact")
- F-041 `registerMMCrate` — publishes `OnMMCrateDetected`

## Pattern (pilot — validate in CI first)

- Capture events by subscribing to `EventDispatcher.getInstance()` around the call, then
  `unsubscribe` (see `crate_manager_spec.lua` `spawnCrate` block for the proven approach).
- `unloadCrate`/`dropCrate`(safe) re-spawn a DCS static → mock `coalition.addStaticObject` +
  `StaticObject.getByName` in `before_each`/`after_each` (same as the `spawnCrate` describe block).
- Reset `cm.crates = {}` in `before_each`.

## Acceptance criteria

- [ ] `luac5.1 -p` clean.
- [ ] Covers F-027/028/030/041 (pilot subset — no static respawn) AND F-029/031/032 (with the
      addStaticObject mock).
- [ ] Each manager method asserted on: state transition + event payload (count + key fields) +
      at least one guard (no-op / no event on invalid input).
- [ ] `busted` job green in CI.

## Blocked by

None. First ticket — its green CI run validates the busted pattern for tickets 02–06.
