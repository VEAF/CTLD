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

- **`U-108_modValidatorHeliportProbeOffMap.lua` (C3) — not safely re-runnable within one DCS
  session** (found 2026-07-10). This test spawns a real "ghost" DCS airbase to detect whether a
  Heliport type is installed (`world.getAirbases()`, name prefix `CTLD_MVP_`), then asserts
  exactly one new ghost appeared since the probe. Ghost airbases are never cleaned up (DCS has
  no API to destroy an airbase), and are named by an incrementing `_probeIdx` that resets to 1
  every time the test resets `CTLDModValidator._instance` — so re-running this test multiple
  times in the same live mission (as our long test session did) creates duplicate
  `CTLD_MVP_H1`/`CTLD_MVP_H2` entries and breaks the before/after diff assertion on the 2nd+ run.
  Confirmed: 13 leftover `CTLD_MVP_*` ghost airbases accumulated in `Test_CTLDNEXT_01.miz`'s
  live session by the time we found this. Not a code bug — a test-repeatability limitation
  inherent to spawning real, permanent DCS objects. Needs a design decision (e.g. only safe to
  run once per mission load / on the runner's own `--no-ai` first pass — not something we should
  decide alone).

- **`U-108_modValidatorHeliportWarnAndSkip.lua` (C1) — asserts the wrong condition** (found
  2026-07-10). C1 expects `_collectTypeNames()` to return **zero** `probeType == "HELIPORT"`
  entries. But per the actual design (`src/core/CTLD_modValidator.lua:124-137`), Heliport
  registry entries are only excluded when they carry `probeSkip = true` (reserved for
  third-party mod heliports DCS can't reliably auto-probe) — stock types like `SINGLE_HELIPAD`
  are *expected* to appear with `probeType == "HELIPORT"` and get auto-probed normally (that's
  exactly what the sibling `ProbeOffMap` test's C1 checks, successfully). Live check: 3 real
  entries currently pass through un-skipped (`Invisible FARP`, `SINGLE_HELIPAD`, `FARP`). Given
  the test's own name ("WarnAndSkip"), it most likely should assert something like "every
  HELIPORT entry *with `probeSkip=true`* is excluded from `entries`, and a WARN fires for each"
  — not "no HELIPORT entries at all". Rewriting it correctly needs knowing which registry
  entries are *supposed* to carry `probeSkip=true` — a config/data decision, not guessed here.
