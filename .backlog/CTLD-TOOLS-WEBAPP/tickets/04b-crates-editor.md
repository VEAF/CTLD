# 04b — crates editor (spawnableCrates)

Status: ✅ done
Type: tool (frontend) + test

> Core fields + add/remove + live validate + tooltips + mixedSet display shipped, verified live.
> `specificParams` (drone-JTAC orbit) inline editing and reorder are deferred as polish — noted in
> 04e's coverage pass. Datamine unit picker is 04d (unit is a text field here).

Edit `spawnableCrates` (family → list of crate entries) in the Data screen.

- Per-entry fields (from FullGas + `tableFields`): `desc`, `unit` (datamine type picker), `weight`,
  `cratesRequired`, `side`, `isJTAC`, `spawnAs`, and JTAC `specificParams` (alti / orbitRadius* /
  speed). Add / remove / reorder entries within a section.
- Live `validate` surfaces unknown units, weight collisions, and mixedSet dangling weights (lot-2).
- Field tooltips from the schema `tableFields` descriptions (EN/FR).

Files: `tools/ctld-tools/web/**`. Depends on: 04a.
