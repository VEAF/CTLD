# 01 — Keep the installed sounds in the mission

**Status:** done
**Lot:** FIX-INSTALL-SOUND-ORPHANS

## Problem

`install()` writes both `.ogg` files into `l10n/DEFAULT/` and declares neither. Reported by Zip: "j'ai
injecté CTLD dans une mission mais il n'a pas mis les sons ogg", then diagnosed by him — "il faut un
trigger qui charge les sons sinon les fichiers disparaissent".

He is right, and the original reasoning was wrong at the level of the *lifecycle*, not the API: a
`.ogg` genuinely needs no resource key to be **played**, which is what VMCT's code and comments say
and what `install.py` quoted. It needs one to **survive** an editor save. VMCT's own
`_find_community_sound_resource_keys` exists precisely to manage a legacy "community sound preload"
trigger — the mechanism this install was missing, and which I read past.

## Change

- `SOUND_KEYS`: one stable resource key per sound (`CTLD_MapKey_Sound_beacon`, …), declared in
  `mapResource` alongside the engine and the configuration.
- `_sound_trigger()`: a MISSION START trigger with one `a_out_sound(getValueResourceByKey(key), 0)`
  action per sound, written in both shapes DCS keeps (`trig` compiled + `trigrules` editor form).
- Installed at rank 3, after configuration and engine: nothing depends on when it runs, only that the
  reference exists. Registered in `rebuild_triggers` with its own marker, so a re-install replaces it.
- The install report lists a third trigger, `sounds`.

## Verification

- `test_every_payload_gets_a_resource_key` — replaces the old
  `test_scripts_get_a_resource_key_and_sounds_do_not`, which asserted the defect.
- `test_a_mission_start_trigger_references_each_sound` — both shapes agree.
- `test_installing_into_a_mission_with_no_sounds_writes_them` — the reported case, on a mission
  stripped of its sounds.
- Manual proof on a real mission: before, `mapResource` held only `ResKey_Action_7`; after, both
  `CTLD_MapKey_Sound_*` keys and both files (420 104 and 9 400 bytes).

## Left to the user

Only DCS itself can confirm the editor now keeps the files across a save — worth one open/save/reopen
cycle in the Mission Editor.
