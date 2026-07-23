# 03 — Crates editor (spawnableCrates)

Status: ready

## What to build

Add the Crates section to the catalogue tree and its corresponding form. The MM can
browse all crate families and individual crate entries, edit any existing crate, add a
new crate to a family, or mark a default crate for removal — all without knowing the
underlying YAML structure.

End-to-end behaviour:
- Tree node "Crates" expands to family sub-nodes (Combat Vehicles, Artillery, Support,
  SAM short range, Drones). Each family expands to its crate entries.
- 4 visual states per entry: default / modified* / added (green) / deleted (strikethrough).
- Clicking a crate entry opens the form pre-filled with all its attributes: `unit`
  (filterable DCS type picker), `desc`, `weight_kg`, `cratesRequired`, `side`, `isJTAC`,
  `spawnAs`, and — for drone crates — a `specificParams` group of fields inline (no
  sub-navigation).
- Apply / Delete (marks for removal) / Cancel. For a deleted entry: Restore replaces
  Delete.
- Clicking a family node shows an "Add entry" button; the form opens blank for a new
  crate in that family.

## Acceptance criteria

- [ ] Tree renders all crate families from `Reference.spawnableCrates`; families expand
  to list their crate entries by `desc`.
- [ ] All 4 visual states applied correctly on tree rows (verified by
  `test_catalogue_tree.py` extended for crates).
- [ ] Crate form exposes all attributes; `unit` field uses a filterable DCS type picker
  (reusing the existing `FilterablePicker` logic ported to tkinter).
- [ ] `specificParams` sub-object rendered as a labelled inline field group within the
  form (no modal, no sub-navigation).
- [ ] Apply commits an add or patch to `EditModel`; tree entry updates its visual state
  immediately.
- [ ] Delete on a default-catalogue crate marks it for removal (state `deleted`);
  strikethrough style applied in tree.
- [ ] Restore on a deleted entry un-marks it (state returns to `default`).
- [ ] Delete on an added entry removes the addition entirely from the tree.
- [ ] Add entry from family node: blank form opens, Apply creates a new entry with state
  `added` (green) in the tree under that family.
- [ ] Inline validation errors appear under the relevant field (e.g. unknown DCS type).
- [ ] `test_catalogue_tree.py` extended: crate add / modify / delete states round-trip.

## Blocked by

- Ticket 02 (scalars editor — establishes tree + form infrastructure)
