# 04b — crates editor (spawnableCrates)

Status: 📋 todo
Type: tool (frontend) + test

Edit `spawnableCrates` (family → list of crate entries) in the Data screen.

- Per-entry fields (from FullGas + `tableFields`): `desc`, `unit` (datamine type picker), `weight`,
  `cratesRequired`, `side`, `isJTAC`, `spawnAs`, and JTAC `specificParams` (alti / orbitRadius* /
  speed). Add / remove / reorder entries within a section.
- Live `validate` surfaces unknown units, weight collisions, and mixedSet dangling weights (lot-2).
- Field tooltips from the schema `tableFields` descriptions (EN/FR).

Files: `tools/ctld-tools/web/**`. Depends on: 04a.
