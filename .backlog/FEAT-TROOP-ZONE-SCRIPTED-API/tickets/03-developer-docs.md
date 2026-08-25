# 03 — developer docs (EN+FR)

**Status:** ⬜ ready

## Why

`createExtractZone` and `registerFOBAsLogistic` — the two existing precedents this method follows
— are both documented only in the developer docs (confirmed: neither appears anywhere under
`docs/mission-maker/`, which covers the `TRZ_…` naming convention for editor-placed zones but not
the scripted constructors). `createTroopZoneAtObject` should land in the same four files, not a
new location.

## What changes

- `docs/developer/api-reference.md` + `.fr.md` — one row in the flat `CTLDZoneManager` method
  table (same table `createExtractZone` and `registerFOBAsLogistic` already sit in), giving
  signature + one-line description.
- `docs/developer/subsystems/zones.md` + `.fr.md` — the narrative page: an entry in the zone-kind
  table (same row style as the existing `EXZ (dynamic)` / `createExtractZone()` row), plus a short
  runtime-usage snippet alongside the existing `zm:createExtractZone(...)` /
  `zm:registerFOBAsLogistic(...)` snippets, covering at least one non-zone example (e.g. a FARP by
  name) since that's the part this method adds over `createExtractZone`.

## Acceptance

- All four files mention `createTroopZoneAtObject`, its signature, and what each of the four
  resolvable object kinds means for anchoring — consistent with ticket 02's actual behavior, not
  aspirational.
- FR pages read naturally in French, not a mechanical translation of the EN page's sentence
  structure (matches the project's existing bilingual-docs bar elsewhere in these same files).

## Blocked by

- Ticket 02 (`createTroopZoneAtObject`) — docs describe the shipped, tested behavior.
