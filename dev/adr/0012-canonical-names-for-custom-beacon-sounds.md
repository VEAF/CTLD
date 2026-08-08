# ADR 0012 — Canonical file names for custom beacon sounds

**Date:** 2026-08-08
**Status:** Accepted
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Context

`radioSound` and `radioSoundFC3` name the `.ogg` files the engine plays through
`trigger.action.radioTransmission("l10n/DEFAULT/" .. ctld.gs("radioSound"), …)`
(`src/CTLD_beacon.lua:280`). Until this lot they were plain text fields: a Mission Maker could
retype the name, but nothing put a file of that name into the mission — the tool only ever installed
the two bundled defaults. Choosing one's own beacon sound therefore meant editing the `.miz` by hand.

The lot makes the choice first-class: pick a file, and the tool injects it and points the
configuration at it. That raises the question of **what the file is called once inside the mission**,
and the answer has to survive a round trip — an installed mission is reopened later, possibly on
another machine, and must still be reconfigurable (the guarantee `FEAT-ONE-CLICK-INSTALL` and
`state.load_path` establish for the configuration itself).

The tool derives "this sound is customised" from the configuration alone: no `source: default|custom`
key exists, because the engine reads only `radioSound`, and a second key describing the same fact can
disagree with it. That derivation is what makes the file name load-bearing.

## Decision

**A sound chosen through the tool enters the mission under a reserved name**, whatever it is called
on the Mission Maker's disk:

| Setting | Default | Customised |
|---|---|---|
| `radioSound` | `beacon.ogg` | `CTLD_beacon_custom.ogg` |
| `radioSoundFC3` | `beaconsilent.ogg` | `CTLD_beaconsilent_custom.ogg` |

The original file name is kept **as a label only**, in `radioSoundOriginalName` /
`radioSoundFC3OriginalName`, declared in `CTLD_config_schema.yaml` and **not** in the default
catalogue — the precedent is `i18n_lang` (schema line 26, absent from `CTLD_config.yaml`), and the
reason is `FIX-TOOL-I18N-LANG`: a key in the default catalogue is a *parameter* under ADR 0011
Addendum 1, so the completeness rule would demand it and every configuration authored before this lot
would report a missing setting at mission start.

These labels are descriptive. Nothing reads them but the interface, and when a label and
`radioSound` disagree, `radioSound` wins and the label is stale.

Typing a file name by hand remains supported and untouched: a Mission Maker who adds an `.ogg`
through the DCS Mission Editor and names it in the configuration keeps working exactly as before.

## Considered options

- **Keep the original file name.** Rejected on one ordinary case: a Mission Maker whose own file is
  called `beacon.ogg`. The configuration would then hold the default value while the mission holds a
  different file, the tool would conclude "default" on reopening, and the next install would silently
  overwrite the Mission Maker's sound with ours. Also lets spaces and non-ASCII characters
  (`Ma Balise Été.ogg`) into a path the engine builds by string concatenation.
- **Original name, prefixed and sanitised** (`CTLD_custom_Ma_Balise_Ete.ogg`). Removes the collision
  and keeps a recognisable name, at the price of a transliteration rule to write, test and maintain —
  including what happens when two different files sanitise to the same name.

## Consequences

- Reopening an installed mission needs no metadata: the reserved name *is* the marker. The tool
  reads `radioSound`, finds the file in the archive, and can reinstall it identically — on another
  machine, months later, with the original file deleted.
- A `.yaml` saved on its own cannot carry the sound (a binary has no place in the configuration
  document). Opening such a configuration and installing it into a mission that does not already
  hold the file is a blocking validation error, resolved by choosing the file again.
- The Mission Maker sees `CTLD_beacon_custom.ogg` inside the archive rather than their own file
  name. The interface shows the original name, which is what `radioSoundOriginalName` exists for.
- Resource keys still derive from the file name, so switching between default and custom leaves the
  previous `.ogg` and its `mapResource` entry behind until the Mission Editor drops them on its next
  save. Deliberate: the alternative was for the tool to delete files from a Mission Maker's archive,
  and nothing in the mission or in game depends on the leftover.
