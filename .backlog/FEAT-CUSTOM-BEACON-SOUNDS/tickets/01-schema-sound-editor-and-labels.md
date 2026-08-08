# 01 — The schema declares the sound editor and the original-name labels

**Status:** todo
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Problem

`radioSound` / `radioSoundFC3` are ordinary strings, so the interface gives them a text box. Nothing
in the schema can say "this setting is a file". And once a chosen sound enters the mission under a
reserved name (ADR 0012), the name it had on the Mission Maker's disk has nowhere to live.

## Change

- A new schema field **`editor:`**, documented in the header comment alongside `choices` / `unit`,
  with `sound` as its first value, set on both sound settings. An accessor in `schema.py`
  (`Schema.editor(key)`), exposed through `/api/schema` like the other metadata.
- **`radioSoundOriginalName`** and **`radioSoundFC3OriginalName`**, declared in
  `src/CTLD_config_schema.yaml` **only** — never in `src/CTLD_config.yaml`. They are labels: written
  when a sound is customised, absent otherwise, and read by nothing but the interface.

Why schema-only rather than catalogue: a scalar in the default catalogue is a *parameter* under ADR
0011 Addendum 1, so `_validate_completeness` would demand it and every configuration authored before
this lot would report a missing setting at mission start — `FIX-TOOL-I18N-LANG`'s wall, paid once.

## Acceptance

- [ ] `Schema.editor("radioSound") == "sound"`; a setting without the field returns `None`.
- [ ] The two label keys are absent from `src/CTLD_config.yaml`, so `validate` on an untouched
      pre-lot configuration reports nothing new (test with a `2.0.0-rc6` config).
- [ ] The header comment of the schema documents `editor:`.
