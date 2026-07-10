# Notes for FullGas

Running log of findings that need FullGas's input before we act on them (original author
context, intent behind legacy test/mission design) — not published, internal working note.

## Test suite (`tests/dcs/`)

- **194 dead FullGas relics** under `tests/dcs/noPlayer/` (dangling `dofile` of
  `DCS-CTLD_FG/recette/setup.lua`, no `ctld_test` framework present, hardcoded
  `C:/Users/Moi/...` paths). Never re-tooled at the VEAF bootstrap. Planned purge tracked as
  backlog lot `CLEANUP-LEGACY-DCS-TESTS` — **talk to FullGas before deleting** in case any are
  worth resurrecting rather than discarding.

- **`scenario_fq_vehicle_whole_transport.lua` (F-Q-5/F-Q-6) — likely obsolete test**
  (found 2026-07-10, first live dcs-bridge run). F-Q-5 expects
  `CTLDCrateManager:refreshRequestEquipmentSection()` to set `spawnAsVehicle=true` for a C-130
  player, but that function *hardcodes* `spawnAsVehicle = false` with an explicit comment:
  "Request Equipment always spawns crates, never a whole vehicle. Feature Q whole-vehicle spawn
  is handled by the dedicated 'Load Vehicle' menu." (`src/CTLD_crate.lua:2752-2754`). Either the
  test predates that menu split and was never updated, or it was meant to target the "Load
  Vehicle" menu-building function instead and got pointed at the wrong one. David's read: likely
  just an obsolete test — flagging for FullGas rather than guessing at a fix, since the original
  intent behind F-Q-5/F-Q-6 isn't obvious from the code alone.
