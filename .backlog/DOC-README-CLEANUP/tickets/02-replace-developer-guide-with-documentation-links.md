# 02 — Replace `Developer Guide` with a `Documentation` quick-links section

Status: done
Type: AFK

## What to build

Replace the `## Developer Guide` prose block (which duplicates content already published on the
documentation site) with a `## Documentation` section containing three quick links:

- Pilot guide: `https://veaf.github.io/CTLD/dev/pilot/`
- Mission maker guide: `https://veaf.github.io/CTLD/dev/mission-maker/`
- Developer documentation: `https://veaf.github.io/CTLD/dev/developer/`

Self-contained: this only touches the last `## Developer Guide` / `## Documentation` heading and
its own single line in the Table of Contents — independent of the Crate Operations cluster
restructured in ticket 03.

## Acceptance criteria

- [x] `## Developer Guide` no longer exists in `README.md`.
- [x] `## Documentation` exists in its place with the three links above.
- [x] All three links resolve correctly (verified live — pilot/mission-maker/developer guide pages
      load with the expected headings).
- [x] The Table of Contents entry for this section is updated accordingly.

## Blocked by

None - can start immediately.

## Implementation

Done in commit `1d528dd` on `fix/doc-readme-cleanup`. Links verified live via WebFetch before
merging (all three resolve to their respective guide pages).
