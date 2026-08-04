# 01 — The sound preload plays to a country the mission does not use

**Status:** done
**Lot:** FIX-PRELOAD-AND-INSTALL-DOCS

## Problem

`FIX-INSTALL-SOUND-ORPHANS` gave each beacon sound a MISSION START reference so the Mission Editor
would stop dropping the files. It used `a_out_sound`, which plays to **everyone** — so every player
connected when the mission starts hears a beacon tone.

Zip had asked for exactly the right thing ("pour une coalition sans unité"). I searched the coalition
predicates, found `coalitionlist` takes only `blue` or `red` across 491 missions, and wrote in the
code that the request "cannot be expressed generically". That conclusion was wrong, and the evidence
against it was in this repository: the README's manual-install section says *"add two Sound to Country
actions (pick an unused country like Australia so no player hears them at mission start)"*. The axis
is the **country**, not the coalition.

## Change

- `a_out_sound_c(<country>, getValueResourceByKey(key), 0)` compiled, `countrylist` in the editor
  form — shape read from real missions (1274 occurrences), not guessed.
- `_silent_country(mission)` picks the id: `SILENT_COUNTRIES = (89, 21)` — Peru, the VEAF mission
  set's de-facto choice (363 uses), then Australia, the one the README names — falling back to any id
  the mission does not declare. Ids from the datamine country table via VMCT's generated
  `dcs-countries.yaml`, per the repo rule on DCS data.
- `_mission_countries()` reads `coalition.<side>.country`, handling both the list and dict shapes
  luadata produces.

Choosing per mission rather than fixing one country is the point: address the sound to a country that
*is* in the mission and the bug comes straight back.

## Verification

- `test_the_preload_plays_to_a_country_the_mission_does_not_use` — on the fixture mission.
- `test_a_taken_preferred_country_is_skipped` — Peru taken → Australia; both taken → neither.
- `test_a_mission_start_trigger_references_each_sound` — updated to the new predicate, both shapes.
