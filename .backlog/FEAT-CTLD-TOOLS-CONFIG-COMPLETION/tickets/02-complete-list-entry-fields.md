# 02 — Complete the missing fields of list entries according to the config version

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-CTLD-TOOLS-CONFIG-COMPLETION](../PRD.md). [ADR 0011](../../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md)
point 5 and Addendum 1. Stories 3, 4, 5, 7, 9, 11.

## What to build

The second slice of **Config completion**, for the tier where "absent" can mean either "removed on purpose" or
"written before the field existed": the fields inside list entries (the aircraft capabilities
`crateSpawnSector` and `crateSpawnDistance`, the crate model `size`).

The version-gap detection looks at the fields of list entries and not only at the flat top-level keys. The
catalogue version moves to `2.1.0`. When a configuration's version tag is older than the catalogue's, each entry
whose key the catalogue knows gains the fields the catalogue's entry has and the stored one lacks, with the
catalogue default. An entry the catalogue does not know (an aircraft type or a crate the Mission Maker added) is
never touched. When the version is current, a missing field is the Mission Maker's own removal and is respected.
A present value is never changed; a catalogue default that differs is reported for information and not applied.

The opening summary of ticket 01 also lists these additions, grouped by aircraft type, each undoable.

## Acceptance criteria

- [x] Opening a `2.0.0` configuration whose Mi-8MT, UH-1H, C-130J-30, CH-47Fbl1 and Mi-24P entries lack the crate
      spawn fields returns them with the catalogue's sector and distance.
- [x] The default crate models gain their `size`.
- [x] A custom aircraft type or crate absent from the catalogue is left exactly as it was.
- [x] A configuration already at `2.1.0` that lacks a list field is not completed (the removal is respected).
- [x] A value already present in an entry keeps its value; a differing catalogue default appears as information
      only.
- [x] The summary groups the added fields by aircraft type and each addition can be undone.
- [x] Saving writes `2.1.0`, so reopening the saved file adds nothing.
- [x] A list or an entry missing altogether is not re-created.
- [x] ctld-tools tests, `ruff check`, `ruff format --check`, `npm run check` pass.

## Blocked by

- [01 — Complete the missing scalar parameters](01-complete-scalar-parameters.md)
