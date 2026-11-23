# 01 — Spawned units can be driven, behind a setting (#327)

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #327.

## What to build
Setting `spawnedUnitsPlayerCanDrive` (default `true`) read at the gesture spawn sites listed in the PRD; `configVersion` 2.5.0 + shape file; schema and settings docs EN+FR; CHANGELOG *Changed*.

## Acceptance criteria
- [ ] Dropped troops, JTAC team, transported vehicle, unpacked crate and AA system are spawned with `playerCanDrive = true` by default, `false` when the setting is `false`.
- [ ] A 2.4.0 configuration without the key gets `true`.
- [ ] `test_catalogue_shape.py` passes.
