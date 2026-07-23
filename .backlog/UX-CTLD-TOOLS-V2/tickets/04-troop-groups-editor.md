# 04 — Troop groups editor (loadableGroups)

Status: ready

## What to build

Add the Troop Groups section to the catalogue tree. The MM can browse, edit, add and
remove troop group templates without touching YAML or knowing the group's internal
structure.

End-to-end behaviour:
- Tree node "Troop Groups" expands to list all `loadableGroups` entries by `name`.
- 4 visual states per entry.
- Clicking a troop group entry opens the form: `name` field + one numeric input per
  unit type (`inf`, `mg`, `at`, `aa`, `mortar`, `jtac`). Empty counts are omitted from
  the generated YAML (same behaviour as v1).
- Apply / Delete / Cancel. Restore for deleted entries. Add from the "Troop Groups"
  node.

## Acceptance criteria

- [ ] Tree renders all `loadableGroups` entries from `Reference` by name; 4 visual
  states applied correctly.
- [ ] Form exposes `name` + 6 count fields; empty inputs treated as absent (not written
  to YAML).
- [ ] Apply commits add or patch to `EditModel`; tree state updates immediately.
- [ ] Delete marks a default troop group for removal (strikethrough); Restore un-marks.
- [ ] Delete on an added group removes it entirely.
- [ ] Add from "Troop Groups" node: blank form, Apply creates new entry (green in tree).
- [ ] `test_catalogue_tree.py` extended for troop group states.

## Blocked by

- Ticket 02 (scalars editor)
