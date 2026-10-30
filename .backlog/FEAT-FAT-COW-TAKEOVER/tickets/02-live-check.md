# 02 — Live check in DCS

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FEAT-FAT-COW-TAKEOVER](../PRD.md).

## What to check

The unit specs mock DCS; three things only DCS can answer:

1. A cow on the ground sent home lifts off and flies home, instead of vanishing on the spot (the 2026-10-29 bug), and despawns once there.
2. A grounded cow given a `Follow` task by a take-over lifts off and follows the new flight.
3. The message and the **Take over a Fat Cow** command reach a client of another flight, and the command leaves the menu once used.

## Kit

`Test_FatCow_LiveCheck.miz` (FEAT-FAT-COW ticket 06, on Zip's machine), rebuilt with this branch's `CTLD.lua`: slots `Gunfighter`, `Apache-150m`, `Apache-300m` in the `LGZ_cowbase_B` logistic zone, the AI flight `Hawk` and its mission-placed cow `Fat Cow Hawk`.
Or the server variant on Privé 1 with this build: any two AH-64D slots in different groups.

## Procedure

**Print Screen** where marked 📸. Nothing to copy: `dcs.log` and the screenshots are read afterwards.

### A — The flight is lost while its cow serves on the ground (the 2026-10-29 case)

1. Slot **Gunfighter**. Take off and land about 3 km out of the zone, on open ground.
2. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Request a Fat Cow** → the first loadout.
   Wait for the cow, then **Fat Cow** → **Land here**, and wait for `Fat Cow FARP open: …`.
3. **Esc** → **Choose slot** → **Spectators**: Gunfighter has no player, its flight is lost.
4. **F10** map, 30 s later: the cow is no longer on the ground at your landing spot, it flies back towards the zone. 📸
   If it is still there, note whether it has its crew and FARP around it.
5. Slot **Apache-150m** before the cow is home (about 1 min at its speed for 3 km: go straight in).
   `\` → **F10 Other** → **CTLD** → **Fat Cow**: **Take over a Fat Cow** is the last entry. 📸
6. **Take over a Fat Cow**: expected `Fat Cow joining your flight: … km, in about … min, with …`.
   **Fat Cow** again: **Take over a Fat Cow** is gone. 📸
7. Take off: the cow turns back and follows you. **Land here**: it lands next to you and opens its FARP a minute later.

### B — Back home

8. With the cow on the ground and its FARP open, **Fat Cow** → **RTB**.
9. **F10** map: the cow lifts off, flies to the zone, lands there and disappears. 📸

### C — The message, with a second player (Griffin or Paluche), or the AI flight

10. Player 1 in **Gunfighter**, player 2 in **Apache-300m**: player 2 requests a cow, lets it land next to him, then leaves his slot.
    Player 1 gets, within a few seconds, `A Fat Cow lost its flight and is going home to LGZ_cowbase_B: … km at …° from you, with …`. 📸
    Without a second player: Claude kills the `Hawk` leader through the bridge (`trigger.action.explosion` on its position) once `Fat Cow Hawk` has landed with it, while Zip sits in **Gunfighter**; the message then says "going home" without a zone name (a mission-placed cow).

## Log lines expected (`dcs.log`)

- `CTLDFatCowManager: cow '…' lost flight '…', going home, offered for take-over`
- possibly `CTLDFatCowManager: cow '…' landed … m from home: not despawned` right after (the event that despawned the cow on 2026-10-29)
- `CTLDFatCowManager: cow '…' taken over by flight 'Apache-150m' (was 'Gunfighter')`
