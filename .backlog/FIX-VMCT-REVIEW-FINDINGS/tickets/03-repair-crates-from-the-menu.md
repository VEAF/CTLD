# 03 — Repair crates can be requested from the menu (#324)

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #324.

## What to build
In the Request Equipment menu (`src/CTLD_crate.lua` ~3131 and ~3181), single crates are passed by `weight` and looked up with `findDescriptorByWeight`, as the `multiple` branch does.

## Acceptance criteria
- [ ] "HAWK Repair" (and the five others) requested in a logistic zone spawns its crate.
- [ ] Every other single crate of the default catalogue is still requested correctly (one test iterating the catalogue).
- [ ] CHANGELOG *Fixed* entry.
