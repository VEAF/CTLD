# 04 — Each AA group gets a unique name (#325)

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #325.

## What to build
`CTLDCrateAssemblyManager:_spawnGroup` (`src/CTLD_aasystem.lua` ~840) puts the `groupUid` it already computes into the group name.

## Acceptance criteria
- [ ] Two systems of the same type spawned at the same `timer.getAbsTime()` get two different group names.
- [ ] Rearm and repair (new group over the old one, ADR 0028) still work.
- [ ] CHANGELOG *Fixed* entry.
