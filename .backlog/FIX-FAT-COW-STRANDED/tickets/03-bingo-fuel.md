# 03 — Bingo fuel: a cow low on fuel goes home

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), decision 3.

## What to build
In the 10 s loop, an AI cow in the air (`ctld.utils.inAir`) whose `getFuel()` is below 25 %, and not already returning, goes home through `_returnHome` and its flight reads "The Fat Cow is low on fuel and returns home." (new `ctld.tr` key, four dictionaries). Logged as `WARN` with the fuel fraction. Pilot guide EN+FR: one sentence on it. CHANGELOG *Fixed* entry.

## Acceptance criteria
- [ ] Holding, following or released cow in the air below 25 %: goes home, message once, log once.
- [ ] A cow on the ground, already returning, or at 25 % or more: unchanged.
