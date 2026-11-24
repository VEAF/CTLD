# 01 — Log the orders and phases of an AI cow

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), decision 1.

## What to build
An `INFO` line for every F10 order given to an AI cow (Land here, Take off, Hold here, Join us, RTB, Release, Take over: cow name, order, requesting unit) and for every change of `cow.ai.phase` (old → new). One helper, called where the phase is set.

## Acceptance criteria
- [ ] Each order and each phase change writes exactly one line naming the cow.
- [ ] No line per loop tick (no noise when nothing changes).
