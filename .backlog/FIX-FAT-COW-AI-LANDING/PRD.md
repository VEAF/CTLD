# FIX-FAT-COW-AI-LANDING — an AI Fat Cow lands in a clearing, and a cow dead without an event is forgotten

Status: in progress

## Problem

Found running the FEAT-FAT-COW-TAKEOVER live check (2026-10-30, `Test_FatCow_Takeover.miz`, twice, same spot): the mission cow `Fat Cow Hawk`, sent to land 120 m left of its AI leader at Hawk's first stop, hovered at 13 m, drifted, and struck a map object (id `87975593`, most likely a tree) at about 10 m above the ground.
A probe logged every event naming the cow and its state every second:

```
313 agl=10.1 air=true  life=58 exist=true
313.6 S_EVENT_HIT  ini=Fat Cow Hawk-1 tgt=87975593   (then S_EVENT_KILL, S_EVENT_SCORE, S_EVENT_AI_ABORT_MISSION)
314 agl=9.8  air=true  life=1  exist=false
317 agl=2.6  air=false life=1  exist=false
```

1. **The landing point**: CTLD sends the cow to a fixed offset from the leader (or from the requester of **Land here**, who may well be hovering), wherever that falls: trees included.
2. **The death goes unnoticed**: DCS fired no `S_EVENT_DEAD`, `S_EVENT_CRASH` nor `S_EVENT_UNIT_LOST` for the cow, and CTLD listens to the first two only. The cow stayed registered in phase `landing`: its FARP never opens, its flight is refused a new cow ("Your flight already has a Fat Cow").

## Solution

1. **A clearing around the asked point**: the point 120 m left of the leader is searched for the nearest clearing within 300 m, 30 m clear of scenery, with `Disposition.getSimpleZones` — the undocumented DCS singleton VMCT's `veaf.findSpawnPoint` uses for its helicopter landings (measured on 2026-08-06: its points avoid buildings and forests; `veafAircraftSpawn` HELICOPTER_LZ_SEARCH 300 m, HELICOPTER_LZ_CLEARANCE 30 m). A candidate closer than 60 m to the leader, or on water, is skipped. No singleton, an error, or no candidate: the asked point, as today.
2. **A vanished cow is forgotten**: the 10 s loop that re-syncs the FARPs also checks every AI cow's unit; one no longer in the world is handled as a dead cow (FARP packed and released, flight free to request another, take-over menus updated).

## Definition of done

- Unit specs (`tests/ci/unit/fatcow_ai_spec.lua`): the landing point moves to the nearest acceptable clearing, keeps the asked point without the singleton or on an error, never closer than 60 m to the leader; a cow whose unit is gone is forgotten by the loop and its flight can request another.
- The FEAT-FAT-COW-TAKEOVER live check run on the same kit (ticket 02): the cow lands and lives, and the take-over scenario passes.
- CHANGELOG, pilot doc (the landing spot).

## Out of scope

- Piloted cows: a pilot picks the spot.
