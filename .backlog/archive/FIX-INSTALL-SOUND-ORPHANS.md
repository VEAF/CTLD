# FIX-INSTALL-SOUND-ORPHANS

**Status:** merged (PR #96). Compacted from `FIX-INSTALL-SOUND-ORPHANS/` on 2026-10-09; the ticket files live on in git history.

Two defects reported by **Zip** minutes apart, using the `2.0.0-rc4` exe on a real mission — both capabilities that shipped and that the mission never saw. **The installed beacon sounds vanish**: `install()` wrote both `.ogg` into `l10n/DEFAULT/` and declared neither, on the correct-but-incomplete ground that a sound needs no resource key to be *played*. It needs one to *survive* — the Mission Editor rebuilds the archive from its own model on save and drops orphan files, so the beacons fall silent with nothing to explain it, the exact failure `FEAT-ONE-CLICK-INSTALL` existed to end. Fixed with the preload idiom the VEAF mission set already uses and this repo's own test mission carries (`ResKey_Action_10/11`): a key per sound plus a MISSION START `a_out_sound` reference, **646 occurrences across 491 real missions**, copied rather than invented — and *not* the per-coalition variant first suggested, since `coalitionlist` only ever takes `blue` or `red` (no neutral value in those 491 missions), so "a coalition with no unit" cannot be chosen generically. **And no way to open a `.miz`**: `load_path` has read a mission since rc4, but the dialog filtered on `*.yaml *.yml` and the button said "config **file**", making it reachable only via "All files" — a gap CI could not catch, the native dialog being interactive.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-keep-the-sounds-in-the-mission` | done | 01 — Keep the installed sounds in the mission |
| `02-open-a-mission-from-the-tool` | done | 02 — Let the open dialog list missions |

## PRD

## FIX-INSTALL-SOUND-ORPHANS — the installed sounds must survive the Mission Editor

### Why

Two defects reported by **Zip** within minutes of each other, both while using the `2.0.0-rc4` exe on
a real mission. Neither is a missing feature: in both cases the capability shipped and the mission
never saw it.

1. **The beacon sounds disappear from the mission.** `install()` writes `beacon.ogg` and
   `beaconsilent.ogg` into `l10n/DEFAULT/` and stops there, on the ground that a `.ogg` needs no
   resource key — true at *runtime*, since the engine passes a name to `radioTransmission`. But a
   file no trigger refers to is an **orphan**: the Mission Editor rebuilds the archive from its own
   model when it saves, and drops it. The mission then has silent beacons and nothing says why —
   the exact failure `FEAT-ONE-CLICK-INSTALL` was built to end, reintroduced one layer down.

   The fix is the idiom the VEAF mission set already uses, and which this repo's own test mission
   carries (`ResKey_Action_10/11`): a resource key per sound plus a MISSION START `a_out_sound`
   action referencing it. **646 occurrences across 491 real missions** — copied verbatim rather than
   invented.

2. **No way to open a `.miz`.** `Session.load_path` has read a mission's configuration since rc4
   (both storage shapes), but the open dialog filtered on `*.yaml *.yml` and the button read "Open a
   config **file**…", so no mission was ever listed. The feature was reachable only by switching the
   dialog to "All files" — which nothing announced. A trou d'interface, not a trou de fonction.

### Scope

- A resource key + a mission-start reference per sound, idempotent like the other two triggers.
- The open dialog lists missions, and the button says what it opens.
- Both defects get a test. The sound one gets a test on a mission **stripped** of its sounds, since
  the fixture mission already carries them and would have hidden the bug.

### Out of scope

- Playing the preload to "a coalition with no unit", as first suggested. `coalitionlist` only ever
  takes `blue` or `red` (1557 / 1353 uses across the same 491 missions, no neutral value anywhere),
  so which side is empty depends on the mission and cannot be chosen generically. The global
  `a_out_sound` at mission start is inaudible in practice — nobody has slotted in yet — and it is
  the shape production missions use.
- Making the Mission Editor keep orphan files in general: not ours to fix.

### Acceptance

- Installing into a mission that never carried a beacon sound leaves both files **and** both keys.
- A re-install replaces the preload trigger instead of adding a second one.
- The open dialog's default filter lists `.miz`.
- `pytest`, `ruff format/check`, `mypy`, `npm test`, `tsc`, `svelte-check` all clean.
