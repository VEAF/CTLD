# FEAT-CUSTOM-BEACON-SOUNDS

**Status:** merged (PR #112). Compacted from `FEAT-CUSTOM-BEACON-SOUNDS/` on 2026-10-09; the ticket files live on in git history.

A beacon sound the Mission Maker chooses, instead of a text box naming a file the tool never installs. Grilled with Zip on 2026-08-08: custom is **derived** from `radioSound` (no second key that could disagree with the engine); a chosen file enters the mission under a **reserved name** (**ADR 0012**) because a Mission Maker whose own file is called `beacon.ogg` would otherwise see it silently overwritten; the original name survives as a schema-only label (`FIX-TOOL-I18N-LANG`'s lesson — a catalogue key would make every pre-lot configuration report a missing setting at mission start); the bytes are read at selection and live in the session, so reopening a `.miz` reinstalls them **on another machine with the original file gone**. `OggS` checked, no size cap, nothing deleted from the archive.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-schema-sound-editor-and-labels` | done | 01 — The schema declares the sound editor and the original-name labels |
| `02-session-holds-the-sound-bytes` | done | 02 — The session holds the sound, not a path |
| `03-install-the-chosen-sound` | done | 03 — Install writes the chosen sound under its reserved name |
| `04-validate-the-sound` | done | 04 — A sound that cannot be produced blocks the install |
| `05-the-picker-in-the-interface` | done | 05 — Default or custom, in the interface |
| `06-documentation` | done | 06 — Document the custom sounds |

## PRD

## FEAT-CUSTOM-BEACON-SOUNDS — a beacon sound the Mission Maker chooses

### Why

`radioSound` and `radioSoundFC3` are editable text boxes today, and Zip's verdict on that is fair:
typing a name changes what the engine *plays* (`src/CTLD_beacon.lua:280` builds
`l10n/DEFAULT/ .. ctld.gs("radioSound")`) without putting any such file into the mission. The tool
installs the two bundled defaults and nothing else, so the only way to use one's own beacon tone is
to open the `.miz` by hand — the exact manual step `FEAT-ONE-CLICK-INSTALL` exists to remove.

The ask: a **default / custom** choice per sound, custom opening a file browser, and the chosen
`.ogg` injected the way the defaults already are — file in `l10n/DEFAULT/`, resource key,
MISSION START preload trigger — *and* referenced by the configuration, since it has another name.

The constraint that shapes everything: an installed mission must stay **reconfigurable**. Reopening
a `.miz` that carries custom sounds has to bring them back, on any machine, whatever became of the
Mission Maker's original files.

### Decisions (grilled 2026-08-08)

1. **No new state for "is it custom".** The engine reads `radioSound` alone; a second key describing
   the same fact could disagree with it. Custom is derived from the value.
2. **A chosen sound enters the mission under a reserved name** — `CTLD_beacon_custom.ogg` /
   `CTLD_beaconsilent_custom.ogg`. See **ADR 0012** for why, and for the case that kills the
   alternative (a Mission Maker whose own file is called `beacon.ogg`).
3. **The original name is kept as a label**, in `radioSoundOriginalName` /
   `radioSoundFC3OriginalName`, declared **in the schema only** — `i18n_lang`'s precedent, and
   `FIX-TOOL-I18N-LANG`'s lesson: a key in the default catalogue would make every pre-existing
   configuration report a missing setting at mission start.
4. **The bytes are read when the file is chosen**, not when the mission is written, and they live in
   the session next to the open configuration. Opening a `.miz` extracts them from the archive. One
   notion — *the current sound's bytes* — filled from the disk or from the mission.
5. **A sound the tool cannot produce blocks the install**, with the validation panel offering to
   pick the file. Unless the target mission already holds a file of that name (installed by hand, or
   a reinstall over the same mission), in which case there is nothing to do.
6. **Resource keys keep deriving from the file name, and nothing is deleted** from a Mission Maker's
   archive. A default ↔ custom round trip leaves a dead `.ogg` until the Mission Editor drops it;
   no consequence in game, and the alternative was for the tool to remove files from a `.miz`.
7. **`OggS` is checked**, the file size is not capped. A renamed `.mp3` would give silent beacons
   discovered in flight — the failure family the last three lots eliminated. A cap, on the other
   hand, would be an arbitrary judgement on a Mission Maker's own audio.
8. **The interface is driven by the schema**, through a new `editor: sound` entry — not by two
   setting names hard-coded in a Svelte component (`FEAT-EDITOR-COVERAGE` banned exactly that).

### Scope

Both sounds, independently. Hand-typing a file name stays supported and untouched: a Mission Maker
who adds an `.ogg` through the Mission Editor and names it in the configuration is unaffected.

### Out of scope

- **Carrying the sound in a saved `.yaml`.** A binary has no place in the configuration document;
  decision 5 is what covers the consequence.
- **Any sound beyond the two beacons.** Nothing else in CTLD names an audio file.
- **An engine (`CTLD.lua`) chosen on disk**, dropped during the same grilling: it would pair a new
  engine with the exe's older schema and interface, and `FEAT-DEV-BUILD-CHANNEL` covers the need
  properly.
