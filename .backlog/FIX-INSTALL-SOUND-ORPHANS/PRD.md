# FIX-INSTALL-SOUND-ORPHANS — the installed sounds must survive the Mission Editor

## Why

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

## Scope

- A resource key + a mission-start reference per sound, idempotent like the other two triggers.
- The open dialog lists missions, and the button says what it opens.
- Both defects get a test. The sound one gets a test on a mission **stripped** of its sounds, since
  the fixture mission already carries them and would have hidden the bug.

## Out of scope

- Playing the preload to "a coalition with no unit", as first suggested. `coalitionlist` only ever
  takes `blue` or `red` (1557 / 1353 uses across the same 491 missions, no neutral value anywhere),
  so which side is empty depends on the mission and cannot be chosen generically. The global
  `a_out_sound` at mission start is inaudible in practice — nobody has slotted in yet — and it is
  the shape production missions use.
- Making the Mission Editor keep orphan files in general: not ours to fix.

## Acceptance

- Installing into a mission that never carried a beacon sound leaves both files **and** both keys.
- A re-install replaces the preload trigger instead of adding a second one.
- The open dialog's default filter lists `.miz`.
- `pytest`, `ruff format/check`, `mypy`, `npm test`, `tsc`, `svelte-check` all clean.
