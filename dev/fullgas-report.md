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

- **RECON `scan()` redesign not reflected in F-117/F-118** (found 2026-07-10). Both tests'
  premises directly contradict explicit, documented behavior in `src/CTLD_recon.lua`:
  - **F-117** sets `cfg["reconEnabled"] = false` expecting `scan()` to emit a "disabled"
    message, but `scan()` gates on a *different* key (`reconF10Menu`, line 580) — the code
    comment says why: "Gate: same key as the menu section (reconF10Menu). If the RECON menu is
    visible, scan must work without additional config." `reconEnabled` is a distinct, real
    config key (a separate "master switch", per `CTLD_config.lua:346`) — it's just not what
    `scan()` itself checks. Possibly `reconEnabled` gates a different entry point (F10 menu
    item construction?) and F-117 targeted the wrong function.
  - **F-118** expects `self._activeScans[player]` to become `nil` after a scan with all layers
    disabled, but `scan()` explicitly does *not* clean up in that case anymore (lines 606-613):
    "No early-return when no layers enabled: RECON starts regardless so the player can activate
    layers via menu after Start without needing to restart RECON."
  Both read like a deliberate `scan()` redesign that predates these tests being updated —
  same class of issue as F-Q-5, not a simple rename. Flagging both rather than guessing which
  function F-117 should actually target or what "cleanup" should mean for F-118 now.

- **`scenario_fr_ai_zones.lua` — 7 failures from the `troopStock`/`vehicleStock` scalar→table
  redesign** (found 2026-07-10, after fixing 12 other mechanical bugs in the same file — see
  below). `_loadAIZonesFromConfig` (`src/CTLD_zone.lua:627-714`) now requires `entry.troopStock`
  to be a **table** `{[templateName]=N}` (per-template stock, parsed via `parseStockTable`) and
  *always* hardcodes `pickMaxStock = 0` for AI zones regardless of input (explicit comment:
  "unlimited; per-template stock via `_aiTroopStock`"). The old scalar format (`troopStock = 10`
  meaning "10 units, zone-wide") is no longer read at all for AI zones — `parseStockTable(10)`
  returns `nil` since `type(raw) ~= "table"`.
  - F-R-1.4, F-R-2.4, F-R-4.2, F-R-13.5, F-R-13.8: all assert `zone.pickMaxStock` against a
    scalar `troopStock` input (10, -1, 0, 5) — testing a field/format pair that no longer
    applies to AI zones. Rewriting correctly means testing `zone._aiTroopStock` (the new
    per-template table) instead, which requires deciding what template names/stock values the
    rewritten test should use — not obvious from the code alone.
  - F-R-43.4, F-R-49.9 (same root cause): the G3 validation warning ("isPickup=true with troop
    cargo but troopStock not defined", `CTLD_zone.lua:1462`) only fires when
    `entry.troopStock == nil` (undefined) — never for an explicit `troopStock = 0`. The test's
    docstring says "isPickup + troopStock=0 → WARN" but no such warning exists for the new table
    format (an explicit `{}` or `{All=0}` might be the intended "explicitly disabled" case
    instead — a design call, not obvious from the code).
  - Everything else in this file (12 other failures — a stale `_aiTroopStock`-less pickup-zone
    mock, `core._aiPilotNames` never re-populated after init [same class as the
    `scenario_ai_transport.lua` fix], and a captured-outText-report clobbered by later/duplicate
    `ctld.utils.log` calls in two spots) was a mechanical test-infrastructure bug, fixed directly
    (145→147 checks as previously-dead code paths started running, 19→7 failures remaining).

- **`scenario_farp_countryside_spawn.lua` / `scenario_farp_metal_spawn.lua` — missing mission
  content, not a code bug** (found 2026-07-10, first live dcs-bridge run). Both look up
  `StaticObject.getByName("coord_farp-1")` as a pure coordinate anchor (any static object type,
  used only for its position) and abort with `FAIL: static 'coord_farp-1' not found` since no
  such static exists in `missions/Test_CTLDNEXT_01.miz`. Needs a static named `coord_farp-1`
  added to the mission via the Mission Editor — not something to guess-place without knowing
  the intended location. David's call: note for FullGas rather than block on it now.
