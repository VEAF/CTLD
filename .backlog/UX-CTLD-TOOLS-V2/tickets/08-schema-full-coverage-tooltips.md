# 08 — Schema full coverage + test_schema_coverage

Status: ready

## What to build

Fill every tooltip in the application. By this slice all editor sections exist (tickets
03–07); this slice adds the authoring content (descriptions) that the tooltip helper
(ticket 01) is already wired to display. It also adds the golden test that enforces
completeness going forward.

Work is primarily content (writing descriptions in `CTLD_config_schema.yaml`) plus the
`Reference` accessor and the coverage test.

Specifically, `CTLD_config_schema.yaml` is extended with:
- Descriptions for all `spawnableCrates` entry attributes (`unit`, `desc`, `weight_kg`,
  `cratesRequired`, `side`, `isJTAC`, `spawnAs`, and each `specificParams` sub-field).
- Descriptions for all `loadableGroups` entry attributes (`name`, `inf`, `mg`, `at`,
  `aa`, `mortar`, `jtac`).
- Descriptions for all `capabilitiesByType` entry attributes (~12 fields).
- Descriptions for all named zone fields (building on the positional schema added in
  ticket 06).
- Section-level descriptions for each top-level tree node (used as tree-node tooltips).

`Reference` gains `field_description(table, field, lang)` returning the EN or FR
description string for any known field.

`test_schema_coverage.py` asserts that for every table and every field known to
`Reference`, a non-empty description exists in both EN and FR.

## Acceptance criteria

- [ ] `CTLD_config_schema.yaml` contains non-empty EN + FR descriptions for every
  attribute of: `spawnableCrates`, `loadableGroups`, `capabilitiesByType`, zone named
  fields, and all section node labels.
- [ ] `Reference.field_description(table, field, lang)` returns the correct description
  string and does not raise for any valid `(table, field)` pair.
- [ ] Hovering any field label in any editor form shows its description tooltip (manual
  verification; no automated test required beyond schema coverage).
- [ ] Hovering any tree node (section or entry) shows its description tooltip.
- [ ] `test_schema_coverage.py` passes: iterates all (table, field) pairs known to
  `Reference` and asserts both `en` and `fr` descriptions are present and non-empty.
- [ ] `test_reference.py` extended to cover `field_description`.

## Blocked by

- Ticket 03 (crates editor)
- Ticket 04 (troop groups editor)
- Ticket 05 (aircraft editor)
- Ticket 06 (zone editors)
- Ticket 07 (mission lists + vehicle weights)
