# 01 — report an AI zone dropped because its name is taken

**Status:** done

No dependency.

## Why

See the PRD. The skip is correct; the silence is not.

## What changes

- Detect, at startup, an `aiZones` entry whose `dcsZoneName` matches a zone name that TRZ / WPZ
  discovery will register (or has registered), and report it once.
- Message names both sides: the AI entry that is lost, and the zone that holds the name. A mission
  maker reading `AIZ[2] 'dropzone1': name already registered by TRZ 'TRZ_dropzone1_B_0_nil_0' — entry
  ignored` knows exactly what to rename.
- Severity: `ERROR`, to match the four `entry ignored` messages `_validateZoneNames` already emits for
  AI zones. If the implementer thinks a lost AI zone is less severe than a malformed one, say why in
  the ticket rather than quietly picking `NOTICE`.

## Where — two options, pick one and record it

1. **Extend `_validateZoneNames`.** It already walks `env.mission.triggers.zones` and parses TRZ / WPZ
   names, so the set of names discovery *will* claim is computable there, before any discovery runs.
   Keeps every AIZ diagnostic in one place.
2. **Report at the skip site** in `_loadAIZonesFromConfig`, where `_troopZones` is authoritative and no
   name has to be predicted. Simpler and exact, but splits AIZ diagnostics across two functions.

Option 1 keeps the diagnostics together; option 2 cannot be wrong about what discovery did. Whichever
is chosen, the reasoning goes in the code comment — the next reader will wonder.

## Watch out

- `_loadAIZonesFromConfig` runs **after** `_discoverTRZ` but **before** `_discoverWPZ`, so a WPZ name
  cannot collide today: the AI entry is registered first and it is `_discoverWPZ` that then skips. If
  option 1 predicts WPZ names too, it would report a collision that does not happen. Check the order in
  `init()` before assuming symmetry.
- The legacy `troopZones` pass runs last and drops its own entry on the same guard (PRD, out of scope).
  If the check is free there, mention it; do not build a second mechanism for it.

## Acceptance

- A mission with `TRZ_dropzone1_B_0_nil_0` and an `aiZones` entry on a zone named `dropzone1` produces
  one startup report entry naming both.
- The same mission with the marker renamed (`TRZ_dropmarker1_...`) produces nothing, and both zones
  work.
- No collision → no new message.

## Tests

- busted: colliding TRZ + AI entry → one report entry, and `_troopZones['dropzone1']` is still the TRZ.
- busted: non-colliding names → no entry, and both zones are registered.
- busted: the message names the AI zone and the zone holding the name.
