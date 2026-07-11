# 03 — Restructure the Crate Operations cluster

Status: done
Type: AFK

## What to build

Nest `Virtual Slingload` and `Pack Equipt` inside `Crate Operations` as `###` children, relocate
`AA System Construction` to immediately follow `Crate Operations`, and update every Table of
Contents entry touched by this move — all in the same change. This is kept as a single vertical
slice rather than split by heading: moving one section without updating the ToC and the sibling
moves in the same commit would leave the document's navigation temporarily inconsistent, which
fails the "no broken anchor links" / "ToC reflects the new hierarchy" acceptance bar. The slice is
independent of tickets 01 and 02.

Resulting structure:

- `## Crate Operations`
  - Spawn / Load / Drop paragraphs (unchanged)
  - `### Virtual Slingload` (demoted from `##`, moved here after the Drop paragraph)
  - Unpack paragraph (unchanged)
  - `### Pack Equipt` (demoted from `##`, moved here after the Unpack paragraph)
    - `#### Pack Vehicle` (demoted from `###`)
    - `#### Pack FARP` (demoted from `###`)
- `## AA System Construction` (kept at `##`, relocated to immediately follow `Crate Operations`)

`## Virtual Parachute Drop` and `## FARP Deployment` are left in place — both are cross-cutting
(Troop / Vehicle / Crate Commands) and out of scope for this move.

## Acceptance criteria

- [x] `## Virtual Slingload` and `## Pack Equipt` no longer exist as standalone `##` sections.
- [x] `### Virtual Slingload` then `### Pack Equipt` appear inside `## Crate Operations`, in that
      order.
- [x] `#### Pack Vehicle` and `#### Pack FARP` are nested under `### Pack Equipt`.
- [x] `## AA System Construction` immediately follows `## Crate Operations` in the rendered
      document, and remains at `##` level with its content unchanged.
- [x] `## Virtual Parachute Drop` and `## FARP Deployment` stay at `##` level, untouched.
- [x] Table of Contents entries and nesting match the rendered hierarchy exactly; no broken anchor
      links.
- [x] No section body text is changed (only heading levels and position move).

## Blocked by

None - can start immediately.

## Implementation

Done in commit `1d528dd` on `fix/doc-readme-cleanup`.
