# FIX-FAT-COW-STRANDED — an AI Fat Cow lifted off its FARP and hovered until it ran out of fuel

**Status:** 🟡 ready — analysis and decisions by the control session on 2026-11-24 (below, each with its reason). They are defaults, not questions: apply them unless the code or a measurement proves one wrong, and then say why in the PR.

Reported by Zip through VMCT, Campagne server, evening of 2026-11-22: "a Fat Cow took off again from where its FARP (CTLD Fat Cow 1) had been, and stopped in a hover until it ran out of fuel".

## What the log says

`dcs.log` of the Campagne server, 2026-11-22, UTC, filtered on "Fat Cow" (the file was overwritten at the 22:28 mission restart; these lines are all that is left):

- 15:12:07 cow `Fat Cow Hatay_AH-64D BLK.II_26 #1-1` lands in a clearing 105 m from the asked point.
- 15:25:05 scene `Fat Cow FARP#1` starts; 15:25:07 the cow is deployed, FARP `CTLD_FatCow_FARP_1`, 4,800 kg of fuel.
- 15:54:23 the FARP is packed (`packScene`, 5 objects destroyed); cow `packed`, 4,494 kg left.
- 15:54 → 21:16: no line from `CTLDFatCowManager`.
- 21:16:55 `WARN` cow `… #1-1` is no longer in the world, with no event: forgotten.

## Analysis (control session, from the code at `e2126be`)

- **It is an AI cow**, requested by the flight of the Apache `Hatay_AH-64D BLK.II_26` (the `Fat Cow <flight> #n` name of `requestAICow`). The piloted path of FEAT-FAT-COW-LEAVE-FARP (#286) is not involved. FIX-FAT-COW-AI-LANDING is merged (#278), not in progress.
- **What packed it at 15:54.** On an AI cow, `pack` is called by: the F10 orders **Take off** (orbit where it stands), **Hold here** (orbit over the requester), **Join us** (follow), **RTB** (land at home); the leader's take-off (`_onAITakeoff`, AI flights only, not this one); the orphan return (`_returnHome(cow, true)`, which logs "offered for take-over" — absent). So it was **one of the four F10 orders**, and none of them writes a log line. **Take off** fits the report best: it orbits at the cow's own position, 150 m AGL, 40 m/s — whether a DCS AI CH-47 flies that `Orbit` as a circle or sits in a hover is **not measured**.
- **Why it stayed up for 5 h 20 min.** A holding or following cow waits for the next order forever: nothing in the manager looks at its fuel. If the Apache player left, the orphan check should have sent it home — but that check runs **once, 2 s after** an `S_EVENT_PLAYER_LEAVE_UNIT` / `S_EVENT_DEAD`, and never again. If the client group still answers `getUnit(1)` at that instant, the cow is never sent home. Not measured either.
- **Why "no event".** The 10 s loop (`_forgetVanishedCows`) did its job: the unit vanished without `S_EVENT_DEAD` / `S_EVENT_CRASH` reaching the manager. What DCS fires for an AI helicopter that runs dry is not known; the defect is upstream (it should never have run dry).

## Implementation Decisions

1. **Log every order and every phase change of an AI cow** (`INFO`, cow name, order or phase, who gave it). Reason: the 5 h hole in the log made the cause unprovable; the next report must be readable.
2. **The orphan check also runs in the 10 s loop**, next to `_forgetVanishedCows`, not only 2 s after an event. Reason: one check at a fixed delay is a race against DCS removing the client unit; the loop already exists.
3. **Bingo fuel: a cow in the air with less than 25 % internal fuel (`Unit:getFuel()`) packs nothing, goes home (`_returnHome`) and tells its flight** ("The Fat Cow is low on fuel and returns home."). A constant, not a setting. Reason: whatever the order and whatever the player does, a cow must never fall out of the sky; 25 % of a CH-47 is enough to cross a map. The new text goes through `ctld.tr` and the four dictionaries.
4. **Measure, in the live check, the two premises above**: what an AI CH-47 does with the `Orbit` task of `_orbit` (circle or hover), and whether a client group still answers `getUnit(1)` 2 s after its player leaves (this one needs Zip in a slot). If the orbit is a hover, say so in the PR and propose the fix as a follow-up; do not change the orbit in this lot without the measurement.
- **No ADR.**

## Testing Decisions

- TDD in the existing Fat Cow spec: each order and phase change writes its line; a cow whose flight's group still exists at 2 s but is gone at the next loop tick is sent home; a cow in the air below 25 % goes home and the flight reads the message, a cow on the ground or above 25 % does not.
- Coverage ratchet only goes up; `busted tests/ci/`, luacheck, Lua 5.1 lint, the build, the i18n guard green.

## Tickets

- [01 log the orders and phases](tickets/01-log-orders-and-phases.md)
- [02 orphan check in the loop](tickets/02-orphan-check-in-the-loop.md)
- [03 bingo fuel](tickets/03-bingo-fuel.md)
- [04 live check](tickets/04-live-check.md)
