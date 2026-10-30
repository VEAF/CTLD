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
2. **The cow says it is going home**: when its flight is lost and it still carries something, every player flight of its coalition that could take it over gets a message: where it is from them, what it carries, and the F10 command.
3. **"Take over a Fat Cow"**: shown in F10 > CTLD > Fat Cow to the flights that have no cow, while a cow of their coalition is going home after losing its flight. The nearest such cow joins the flight and serves it as its own (follows it, Land here / Take off / Hold here / Join us / RTB, FARP after the delay).

## Decisions

- **Who is told**: the player flights of the cow's coalition that see the AI Fat Cow menu (every player but a cow pilot) and have no cow, rather than the whole coalition: the message names a command only they can use, and a fighter pilot with a cow already would only read noise.
- **Which cows can be taken**: only a cow that lost its flight and still carries something. A cow sent home with RTB was released on purpose; an empty one has nothing to give.
- **One command, the nearest cow**: rather than one command per cow, whose label would carry long group names.
- **Home radius 2 km**: the Land task puts the cow down at the home point itself; a wrong landing was measured tens of km away.

## Definition of done

- Unit specs (`tests/ci/unit/fatcow_ai_spec.lua`): no despawn away from home; the message to eligible flights only; the command shown while an orphan cow exists and gone once it is taken, home or dead; the take-over re-tasks the cow to follow the new flight, which then commands it.
- Docs (pilot + mission maker, EN + FR), CHANGELOG, i18n (four dictionaries).
- Live check written for Zip (ticket 02).

## Out of scope

- Keeping the FARP open for other flights when the escorted flight is lost.
- Automatic re-attachment to a flight respawning under the same group name (it can take the cow over with the command).
