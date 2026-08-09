# 04 — A sound that cannot be produced blocks the install

**Status:** done
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Problem

Two ways to end up with silent beacons, both invisible until someone flies:

1. the configuration says a sound is customised and the tool has no bytes for it — the ordinary case
   being a `.yaml` saved yesterday and reopened today (the sound never travels in a `.yaml`);
2. the chosen file is not an Ogg — renaming `music.mp3` to `beacon.ogg` takes two seconds and DCS
   plays nothing.

## Change

- **Format**: the first four bytes must be `OggS`, checked when the file is chosen. Anything else is
  refused there and then, with a message naming the file. No size cap (PRD decision 7).
- **Availability**: a customised sound with no bytes in session is a **blocking validation error** —
  the *Install* button is already disabled while an error stands — carrying the action that fixes
  it, i.e. picking the file. Exception: the target mission already holds a file of that name (a
  hand-made install, or a reinstall over the same mission), in which case nothing is missing.

## Acceptance

- [x] A non-Ogg file is refused at selection (422, `OggS` named in the message) and the
      configuration is left pointing at the bundled sound.
- [x] Opening a `.yaml` that names a custom sound, then targeting a mission without it → blocking
      `validate.sound.missing`, install refused.
- [x] Same configuration, but the target mission already holds the file → no error, install allowed
      and the existing bytes rewritten.
- [x] No size cap; the size is reported instead.
