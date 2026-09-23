# 03 — Document `EXZ_` for Mission Makers

**Status:** ✅ done

While drafting, found that `docs/mission-maker/zones.md`/`.fr.md` and
`docs/developer/subsystems/zones.md` all explicitly stated *"there is no separate `EXZ` prefix"*
(true before ticket 02, now stale) — corrected those claims (the zone-types table, the naming-
separator rule's exception, the shared-namespace warning and registration order, and the
developer-facing numbered discovery-algorithm list) in the same PR rather than leaving a
freshly-wrong statement next to the new section.

**Blocked by:** ticket 02 (documents the shipped behaviour, including the naming convention it
adds).

## What to build

Today there is zero concrete configuration example for an extraction zone anywhere in the
published docs — only the bare API signature in `docs/developer/api-reference.md` and prose
mentions of the `EXZ_` prefix as a player-facing behaviour label in `docs/pilot/troop-transport.md`
(confirmed by search during the grill session behind this lot). Add a new "Extraction zones
(EXZ)" section to `docs/mission-maker/zones.md` and `.fr.md`, mirroring the existing "AI transport
zones (AIZ)" section's shape:

- A short role/trigger description (what an extraction zone does, when it fires).
- Both declaration methods, each with a concrete example: the naming convention
  (`EXZ_<name>_<flag>_<smoke>`, from ticket 02) and the scripted API
  (`ctld.createExtractZone(zoneName, flagNumber, smoke)`, already existing).
- A parameters table (flag, smoke — including the `nil` reserved word for each) matching the
  style of the `AIZ_` section's parameters table.
- Setup steps, mirroring `AIZ_`'s "AI transport setup" numbered steps.

## Watch out

- Keep the same tone and structure as the `AIZ_` section immediately above it in the same file —
  a reader moving from one to the other should feel no discontinuity.
- `docs/pilot/troop-transport.md`'s existing `EXZ_` mentions (the silent-drop-into-extract-zone
  behaviour) are player-facing and already correct — don't duplicate that content here, link to it
  if useful, but this ticket's audience is the Mission Maker deciding how to create the zone.
- FR parity is not optional — `zones.fr.md` ships the same section, translated, in the same PR.

## Acceptance

- `docs/mission-maker/zones.md` has a new "Extraction zones (EXZ)" section with both declaration
  methods, a parameters table, and setup steps.
- `docs/mission-maker/zones.fr.md` carries the same section in French.
- The section's example names and parameter values match what ticket 02 actually ships (re-check
  after that ticket lands, don't draft blind and skip verification).

## Tests

Docs-only — no automated test. Manual EN/FR parity review against the `AIZ_` section's structure.
