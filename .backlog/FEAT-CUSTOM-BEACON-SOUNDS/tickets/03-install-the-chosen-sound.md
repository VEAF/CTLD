# 03 — Install writes the chosen sound under its reserved name

**Status:** todo
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Problem

`install()` reads the two bundled sounds from the bundle and writes them under their own names
(`install.py:240`, `install.py:272`). It has no notion of a sound that came from anywhere else, and
`SOUND_KEYS` is a module-level constant built from `resources.SOUND_NAMES`.

## Change

The sounds to write become an **input** of the install rather than a constant read from the bundle:
for each of the two roles, either the default (bundle) or the session's custom bytes, named per
ADR 0012 (`CTLD_beacon_custom.ogg` / `CTLD_beaconsilent_custom.ogg`). The resource key keeps
deriving from the file name, as today — no cleanup of the previous file, deliberately (PRD
decision 6).

The report gains what the Mission Maker needs to check the result: each sound's **name and size**,
and whether it was the default or a chosen file.

## Acceptance

- [ ] A custom install puts `CTLD_beacon_custom.ogg` in `l10n/DEFAULT/`, in `mapResource`, and in
      the preload trigger — same three places as a default one.
- [ ] `radioSound` in the injected configuration matches the file actually written.
- [ ] Reinstalling over the same mission replaces rather than accumulates (existing idempotence
      test, extended to the custom case).
- [ ] Going back to the default restores `beacon.ogg` and leaves the mission playable.
