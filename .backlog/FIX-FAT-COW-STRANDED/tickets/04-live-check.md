# 04 — Live check and the two measurements

**Status:** 🟡 ready · **Type:** HITL for (b) (Zip in a slot), AFK otherwise; Zip launches DCS, the session launches dcs-serve

## Parent
[PRD](../PRD.md), decision 4. Blocked by 01-03.

## What to build
On `Test_CTLDNEXT_01.miz`, over the DCS bridge:

- (a) An AI cow given **Take off**: record its speed and position over two minutes. Circle or hover?
- (b) With Zip in a helicopter slot that requested a cow: Zip leaves the slot; record whether his group still answers `getUnit(1)` at 2 s, 5 s, 10 s, and that the cow goes home.
- (c) Bingo: set the cow's fuel low (or wait with a reduced fuel load) and check it goes home with the message.
- (d) The orders and phases appear in `dcs.log`.

## Acceptance criteria
- [ ] (a)-(d) recorded PASS/FAIL or as measured values, with the log lines.
- [ ] If (a) is a hover, the PR says so and proposes the fix as a follow-up lot.
- [ ] Nothing left in the mission afterwards.
