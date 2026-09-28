# 04 — Developer docs, `CONTEXT.md` finalization, `CHANGELOG.md`

**Status:** ready

**Blocked by:** [03](03-trz-static-unit-group-discovery.md) — needs the shipped behavior to
document accurately.

## What to build

- **Developer docs** (`docs/developer/subsystems/zones.md`/`.fr.md`,
  `docs/developer/api-reference.md`/`.fr.md`): document the static/unit/group `TRZ_` discovery path
  next to `createTroopZoneAtObject` and the existing `TRZ_` convention, so the "how a `TRZ_` can
  come to exist" story (Mission Editor, script, auto-discovery) reads as one coherent place — same
  documentation pattern `FEAT-TROOP-ZONE-SCRIPTED-API` used when it added
  `createTroopZoneAtObject` next to `createExtractZone`/`registerFOBAsLogistic`.
- **`CONTEXT.md`**: the "Auto-discovered zone" (`TRZ_` beyond trigger zones) and "Anchor" (revision
  proposed) entries — both updated during the `grill-with-docs` session (2026-09-28) with
  "proposed, not yet implemented" wording — move to their final wording now that the behavior is
  shipped. Drop the "not yet implemented" qualifier and any now-stale phrasing.
- **`CHANGELOG.md` `[Unreleased]`**: an entry for the new discovery capability (Added), and a
  **separate** entry for the anchor-death real-removal behavior change (Fixed) — the ship/truck
  case existed before this lot and is a visible behavior change on its own, worth its own line per
  the PRD's Further Notes.
- **Mission-maker docs** (`docs/mission-maker/zones.md`/`.fr.md`): check whether the existing
  "Creating a pickup zone at runtime" section (added by `FEAT-TROOP-ZONE-SCRIPTED-API`) needs a
  companion note about the naming-convention path — add one only if it's genuinely useful to a
  mission maker there (a bare naming convention likely needs little more than a one-line pointer,
  unlike the scripted-API's code snippet).

## Watch out

- Both EN and FR versions of every doc file touched — no FR/EN mixing within a sentence (project
  language rule).
- Don't restate implementation details already covered by ADR 0021 or the PRD — link to them rather
  than duplicating the reasoning in the docs.
- Verify the roadmap's own two formalized-lot comments (`dev/roadmap.md`) still point at this lot
  correctly — they were written when the PRD was published; no change expected unless something
  drifted during implementation.

## Acceptance

- `docs/developer/subsystems/zones.md`/`.fr.md` and `docs/developer/api-reference.md`/`.fr.md`
  document the new discovery path.
- `CONTEXT.md`'s two updated entries no longer read "proposed, not yet implemented".
- `CHANGELOG.md` `[Unreleased]` has both the new-capability and the anchor-removal-behavior-change
  entries.
- `docs/mission-maker/zones.md`/`.fr.md` reviewed; updated only if genuinely useful.

## Tests

Documentation-only ticket — no `busted`/`luacheck` impact expected. If `mkdocs` link-checking or a
doc-build CI step exists, it must still pass.
