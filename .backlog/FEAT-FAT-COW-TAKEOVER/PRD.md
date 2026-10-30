# FEAT-FAT-COW-TAKEOVER — a Fat Cow that lost its flight goes home, says so, and can be taken over

Status: merged (PR #277) — 02 waiting-human (live check)

## Problem

An AI Fat Cow (FEAT-FAT-COW) serves the flight that requested it.
When that flight is lost (shot down, or its player leaves), the cow packs and goes home without a word, and nobody else can use it.

On 2026-10-29 it did not even go home.
On "Marteau du Golan" (Syria, Privé 1, CTLD embedded by VMCT 6.34.0), the cow `Fat Cow Rosh Pina_AH-64D BLK.II_10 #1-1`, deployed near MASADA since 21:09:06 UTC, vanished on the spot at 21:25:16 UTC, about a minute after its flight's AH-64D (Paluche) was shot down (21:24:14).
Its crew (`FatCow_Crew_Grp-3`) went the same second.

### Root cause (server `dcs.log`, 2026-10-29)

```
21:25:15.476 CTLDSceneManager:packScene: 'Fat Cow FARP#1' packed (5 object(s) destroyed)
21:25:15.476 CTLDFatCowManager: cow 'Fat Cow Rosh Pina_AH-64D BLK.II_10 #1-1' packed, 4542 kg of fuel left
21:25:16.461 event:type=land, initiator_unit_type=CH-47Fbl1, t=4022.503
```

1. The flight check found the flight gone and called `_returnHome`: the FARP was packed (the crew is one of the scene's five objects, hence its removal) and the cow, still on the ground, was given a Land mission at home and the phase `returning`.
2. DCS fired `S_EVENT_LAND` for the cow 0.98 s later, while it was still sitting at MASADA, tens of km from Rosh Pina.
3. `onLand` treated any landing in the `returning` phase as the arrival home and destroyed the group.

No time limit, no false loss detection: the despawn trusted a landing event without checking where it happened.
A cow released with **RTB** while on the ground was exposed to the same despawn.

## Solution

1. **Despawn only at home**: a returning cow that lands more than 2 km from its home point is left alone (logged with the distance).
2. **The cow says it is going home**: when its flight is lost, every helicopter flight of its coalition that could take it over gets a message: where it is from them, where it goes, what it carries, and the F10 command.
3. **"Take over a Fat Cow"**: a submenu of F10 > CTLD > Fat Cow, for the helicopter flights that have no cow, listing every cow of their coalition flying home (lost flight or RTB, empty or not), nearest first, with its distance from the caller. The cow picked joins the flight and serves it as its own (follows it, Land here / Take off / Hold here / Join us / RTB, FARP after the delay). An entry goes once its cow is taken over, has landed at home, or is dead.

4. **"Release the Fat Cow"** (Zip, 2026-10-30), next to RTB: the cow leaves its flight and stays where it is, FARP open on the ground, orbiting in the air (landing if it was landing). The helicopter flights that could take it over are told, and it is listed as `waiting` until one does; it packs its FARP before it moves.

## Decisions

- **Who is told, who may take over**: the helicopter flights of the cow's coalition that see the AI Fat Cow menu (not a cow pilot) and have no cow (Zip, 2026-10-30: helicopters only). The message names a command only they can use.
- **Which cows can be taken**: any cow flying home, sent with RTB or empty included, until it has landed at home, and any cow its flight released (Zip, 2026-10-30, reversing the first version, which offered only a cow that lost its flight and still carried something).
- **One entry per cow, nearest first, with its distance** (Zip, 2026-10-30). The distance is the one at the menu's last build: the menus are rebuilt when a cow starts home, is taken over, lands home or dies, and every 30 s for the flights that may take one over. A label that changes is a removed entry and a new one: ADR 0027 parks the freed id, so a screen left open across the update fires nothing rather than the wrong cow.
- **Home radius 2 km**: the Land task puts the cow down at the home point itself; the wrong landing was measured tens of km away.

## Definition of done

- Unit specs (`tests/ci/unit/fatcow_ai_spec.lua`): no despawn away from home; the message to eligible flights only; the submenu listing the cows going home, nearest first, to helicopter flights without a cow only, and each entry gone once its cow is taken, home or dead; the take-over re-tasks the cow to follow the new flight, which then commands it.
- Docs (pilot + mission maker, EN + FR), CHANGELOG, i18n (four dictionaries).
- Live check written for Zip (ticket 02).

## Out of scope

- Keeping the FARP open for other flights when the escorted flight is lost.
- Automatic re-attachment to a flight respawning under the same group name (it can take the cow over with the command).
