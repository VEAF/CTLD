# 02 — Live check in DCS

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FEAT-FAT-COW-TAKEOVER](../PRD.md).

## What to check

The unit specs mock DCS; three things only DCS can answer:

1. A cow on the ground sent home lifts off and flies home, instead of vanishing on the spot (the 2026-10-29 bug), and despawns once there.
2. A grounded cow given a `Follow` task by a take-over lifts off and follows the new flight.
3. **Release the Fat Cow** on the ground leaves the cow and its FARP serving where they are, and the cow packs before it follows the flight that takes it over.
4. The message and the **Take over a Fat Cow** submenu reach a client of another helicopter flight (nearest cow first, with its distance), and an entry leaves the menu once its cow is taken.

## Kit

`Test_FatCow_LiveCheck.miz` (FEAT-FAT-COW ticket 06, on Zip's machine), rebuilt with this branch's `CTLD.lua`: slots `Gunfighter`, `Apache-150m`, `Apache-300m` in the `LGZ_cowbase_B` logistic zone, the AI flight `Hawk` and its mission-placed cow `Fat Cow Hawk`.
Or the server variant on Privé 1 with this build: any two AH-64D slots in different groups.

## Procedure

**Print Screen** where marked 📸. Nothing to copy: `dcs.log` and the screenshots are read afterwards.

### A — The flight is lost while its cow serves on the ground (the 2026-10-29 case)

1. Slot **Gunfighter**. Take off and land about 10 km out of the zone, on open ground (the cow then needs about 2.5 min to fly home: time to change slot).
2. `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Request a Fat Cow** → the first loadout.
   Wait for the cow, then **Fat Cow** → **Land here**, and wait for `Fat Cow FARP open: …`.
3. **Esc** → **Choose slot** → **Spectators**: Gunfighter has no player, its flight is lost.
4. **F10** map, 30 s later: the cow is no longer on the ground at your landing spot, it flies back towards the zone. 📸
   If it is still there, note whether it has its crew and FARP around it.
5. Slot **Apache-150m** before the cow is home: go straight in.
   `\` → **F10 Other** → **CTLD** → **Fat Cow** → **Take over a Fat Cow**: one entry, `Fat Cow … km away, going home to LGZ_cowbase_B`. 📸
   Wait 30 s and open it again: the distance went down.
6. Pick that entry: expected `Fat Cow joining your flight: … km, in about … min, with …`.
   **Fat Cow** again: **Take over a Fat Cow** is gone. 📸
7. Take off: the cow turns back and follows you. **Land here**: it lands next to you and opens its FARP a minute later.

### B — Back home

8. With the cow on the ground and its FARP open, **Fat Cow** → **RTB**.
9. On the way, **Fat Cow** → **Take over a Fat Cow** lists it again (an RTB cow can be taken back). 📸
   Do not pick it: on the **F10** map the cow lifts off, flies to the zone, lands there and disappears, and the entry goes with it. 📸

### C — Released on the ground

10. Slot **Gunfighter**, request a cow, **Land here** away from the zone, wait for its FARP.
11. **Fat Cow** → **Release the Fat Cow**: expected `Fat Cow released: …`; the cow and its FARP stay. 📸
12. **Fat Cow** → **Take over a Fat Cow**: `Fat Cow … km away, waiting`. Pick it: the FARP packs (crew and depot gone), the cow lifts off and follows you. 📸

### D — The message, with a second player (Griffin or Paluche), or the AI flight

13. Player 1 in **Gunfighter**, player 2 in **Apache-300m**: player 2 requests a cow, lets it land next to him, then leaves his slot.
    Player 1 gets, within a few seconds, `A Fat Cow lost its flight and is going home to LGZ_cowbase_B: … km at …° from you, with …`. 📸
    Without a second player: Claude kills the `Hawk` leader through the bridge (`trigger.action.explosion` on its position) once `Fat Cow Hawk` has landed with it, while Zip sits in **Gunfighter**; the message then says "going home" without a zone name (a mission-placed cow).

## Log lines expected (`dcs.log`)

- `CTLDFatCowManager: cow '…' lost flight '…', offered for take-over`, or `… released by flight '…', offered for take-over`
- possibly `CTLDFatCowManager: cow '…' landed … m from home: not despawned` right after (the event that despawned the cow on 2026-10-29)
- `CTLDFatCowManager: cow '…' taken over by flight 'Apache-150m' (was 'Gunfighter')`
