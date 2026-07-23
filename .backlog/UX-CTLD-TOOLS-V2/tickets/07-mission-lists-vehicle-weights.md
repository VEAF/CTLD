# 07 — Mission lists + vehicle weights editor

Status: ready

## What to build

Add the Mission Lists and Advanced / Vehicle Weights sections to the catalogue tree.
These are simpler table types (B-2: lists of strings, and a flat dict of name→value
pairs) — their editors are thin but complete the coverage of all configurable tables.

End-to-end behaviour:
- Tree node "Mission Lists" expands to three sub-nodes: "Transport pilots"
  (`transportPilotNames`), "Extractable groups" (`extractableGroups`), "Logistic units"
  (`logisticUnits`).
- Each sub-node lists its string entries. 4 visual states (added/deleted only — these
  lists have no default objects to modify, only to extend or shrink).
- Clicking an entry opens the form: single text field, Apply / Delete / Cancel.
- Add from sub-node: blank text input; Apply appends the string (green in tree).
- Tree node "Advanced → Vehicle Weights" expands to list `groundVehicleWeights` entries
  as "DCS type name → weight kg". Clicking opens the form: type name (filterable DCS
  type picker) + weight field. Full add/modify/delete.

## Acceptance criteria

- [ ] Tree renders `transportPilotNames`, `extractableGroups`, `logisticUnits` as string
  lists under "Mission Lists"; entries show added (green) / deleted (strikethrough)
  states.
- [ ] Add string entry: text input form; Apply appends to `EditModel`; tree shows new
  entry green.
- [ ] Delete string entry: marks for removal (strikethrough); Restore un-marks.
- [ ] Tree renders `groundVehicleWeights` under "Advanced → Vehicle Weights" as
  `type → weight` pairs; 4 visual states.
- [ ] Vehicle weight form: DCS type picker + numeric weight field; Apply / Delete /
  Cancel; Restore for deleted entries; Add from node.
- [ ] `test_catalogue_tree.py` extended for mission list and vehicle weight states.

## Blocked by

- Ticket 02 (scalars editor)
