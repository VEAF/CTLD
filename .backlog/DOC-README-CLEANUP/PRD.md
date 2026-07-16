Status: waiting-human

# PRD — DOC-README-CLEANUP

## Problem Statement

The project README.md has accumulated several structural and naming issues since the codebase moved
from the temporary `DCS-CTLD Next` repository to the definitive `CTLD` repository:

1. The document title still reads `DCS-CTLD Next`, the old temporary repo name.
2. Two sections (`Pack Equipt` and `Virtual Slingload`) are presented at the same hierarchy level
   as `Crate Operations`, even though both are crate sub-operations and already appear under
   **Crate Commands** in the F10 menu description.
3. `AA System Construction` is placed far from `Crate Operations` despite being a multi-crate
   assembly workflow.
4. The `Developer Guide` section is a self-contained prose block that duplicates content now
   published on the documentation site, with no links to the live guides.

## Solution

Apply six targeted edits to `README.md`:

1. Rename the H1 title from `DCS-CTLD Next` to `CTLD`.
2. Demote `## Pack Equipt` to `### Pack Equipt` and move it inside `## Crate Operations`
   (after the Unpack paragraph), reflecting its position under Crate Commands in the F10 menu.
3. Demote `## Virtual Slingload` to `### Virtual Slingload` and move it inside
   `## Crate Operations` (after the Drop paragraph, before Pack Equipt), for the same reason.
4. Keep `## AA System Construction` at `##` level but relocate it to immediately after
   `## Crate Operations` to signal the logical proximity.
5. Update the Table of Contents to reflect changes 1–4.
6. Replace `## Developer Guide` with a `## Documentation` section containing three quick links
   to the live documentation site (pilot guide, mission maker guide, developer documentation).

## User Stories

1. As a new user landing on the GitHub repository page, I want the README title to say `CTLD` so
   that I immediately know I am in the right repository and not a stale fork.
2. As a mission maker reading the README, I want `Pack Equipt` to appear inside `Crate Operations`
   so that I understand packing is part of the crate lifecycle, not a standalone concept.
3. As a mission maker reading the README, I want `Virtual Slingload` to appear inside
   `Crate Operations` so that I find slingload documentation in the same place as crate loading
   and dropping.
4. As a mission maker reading the README, I want `AA System Construction` to appear immediately
   after `Crate Operations` so that the connection between crate assembly and AA system build
   is obvious without scrolling far.
5. As a developer consulting the README, I want the Table of Contents to accurately reflect the
   section hierarchy so that anchor links work and navigation is predictable.
6. As any reader consulting the README, I want a `Documentation` section with direct links to
   the pilot guide, mission maker guide, and developer documentation site so that I can reach
   the full reference without searching.

## Implementation Decisions

- All changes are confined to `README.md`. No source file, test, or build artifact is modified.
- The three subsections of `## Crate Operations` after the edit will be, in order:
  `### Virtual Slingload`, then `### Pack Equipt`. The existing `### Pack Vehicle` and
  `### Pack FARP` headings inside Pack Equipt become `####`.
- `## Virtual Parachute Drop` and `## FARP Deployment` are left at `##` level in their current
  positions: both are cross-cutting (Troop / Vehicle / Crate Commands) and their standalone
  status is justified.
- The `## Documentation` quick-link section uses the production URLs below (English, consistent
  with the rest of the README):
  - Pilot guide: `https://veaf.github.io/CTLD/dev/pilot/`
  - Mission maker guide: `https://veaf.github.io/CTLD/dev/mission-maker/`
  - Developer documentation: `https://veaf.github.io/CTLD/dev/developer/`

## Testing Decisions

This lot contains no logic changes. There is nothing to unit-test or integration-test.

Acceptance criteria (manual review checklist):
- [ ] H1 reads `# CTLD`.
- [ ] Table of Contents reflects the new hierarchy (no broken anchor links).
- [ ] `Crate Operations` section contains `Virtual Slingload` and `Pack Equipt` as `###` children.
- [ ] `AA System Construction` immediately follows `Crate Operations` in the rendered document.
- [ ] `Developer Guide` section is gone; `Documentation` section is present with the three links.
- [ ] No other section has been moved, renamed, or reformatted.

## Out of Scope

- Content edits inside any section (wording, examples, parameters).
- Restructuring sections other than those listed above.
- Adding new documentation pages or updating the docs site itself.
- Any `src/` or `tests/` changes.

## Further Notes

The URLs supplied for the `## Documentation` section point to the `dev/` subdirectory of the
GitHub Pages site deployed by `DOC-MKDOCS`. Verify the links resolve correctly before merging.
