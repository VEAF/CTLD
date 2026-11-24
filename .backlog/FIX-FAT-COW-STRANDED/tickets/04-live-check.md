# 04 — Live check and the two measurements

**Status:** ✅ done 2026-11-24 · **Type:** HITL for (b) (Zip in a slot), AFK otherwise; Zip launches DCS, the session launches dcs-serve

## Parent
[PRD](../PRD.md), decision 4. Blocked by 01-03.

## What to build
On `Test_CTLDNEXT_01.miz`, over the DCS bridge:

- (a) An AI cow given **Take off**: record its speed and position over two minutes. Circle or hover?
- (b) With Zip in a helicopter slot that requested a cow: Zip leaves the slot; record whether his group still answers `getUnit(1)` at 2 s, 5 s, 10 s, and that the cow goes home.
- (c) Bingo: set the cow's fuel low (or wait with a reduced fuel load) and check it goes home with the message.
- (d) The orders and phases appear in `dcs.log`.

## Acceptance criteria
- [x] (a)-(d) recorded PASS/FAIL or as measured values, with the log lines.
- [x] If (a) is a hover, the PR says so and proposes the fix as a follow-up lot.
- [x] Nothing left in the mission afterwards.

## Measured, 2026-11-24 (`Test_CTLDNEXT_01.miz`, DCS bridge, build of this PR)

- **(a) PASS, circle, not a hover.** An AI CH-47 given *Take off* flew at 35.7-42.9 m/s (mean 39.7) over 120 s; its distance from the orbit point grew from 249 m to 1741 m at 120 s and 2077 m at 210 s, its heading turning about 1.2 deg/s: a circle of roughly 1.9 km radius. It burns fuel while it circles. No follow-up lot needed.
- **(b) The client group is gone at once.** Player leaves the slot: at the first sample (0.1 s) and at 2.1 s, 5.1 s and 10.1 s `Group.getByName` already returns nothing (`group=false`, `getUnit(1)=false`), and the cow is already `returning` and no longer registered to the flight. The 2 s check therefore does not race the removal in this setup (a first pass, whose sampler recorded nothing, logged the cow going home 3.1 s after the leave). The 10 s loop check stays as the safety net for the slower cases of the 2026-11-22 incident.
- **(c) PASS.** A CH-47 at 0.13 of its tanks, in the air, registered as the cow of a flight: the 10 s loop sent it home and its flight read "The Fat Cow is low on fuel and returns home." Log: `cow 'Bingo Cow-1' is low on fuel (0.13 of its tanks, phase following): sent home` (WARN), then `phase following -> returning`.
- **(d) PASS.** `dcs.log` shows `cow 'Fat Cow Stranded #1-1' order 'Take off' from 'Stranded-1'`, `phase following -> holding`, and for (b) `cow 'Fat Cow uh1 #3-1' lost flight 'uh1', offered for take-over`.

Nothing is left in the mission: the scenarios destroy their groups and forget their cows, and the player-leave handler is removed.
