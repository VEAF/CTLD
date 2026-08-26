-- .luacheckrc — CTLD project
-- Target runtime: DCS World (Lua 5.1 strict)
-- Run: luacheck src/ tests/ CTLD.lua

std = "lua51"

-- Lua 5.2+ constructs are not available in DCS (Lua 5.1)
-- luacheck will warn on goto, <const>, <close>, table.move, math.type, utf8.*
-- Note: goto itself is a Lua 5.2+ keyword — luacheck's lua51 std already rejects it.

max_line_length = 200
unused_args     = false   -- many DCS callbacks receive args not always used
self            = false   -- OOP methods use self implicitly

-- Files / directories to ignore
exclude_files = {
    "source/**",          -- legacy source, never modified
    "tools/**",
}

-- DCS World API globals (all read-only from script perspective)
read_globals = {
    -- DCS singleton namespaces
    "env", "world", "coalition", "country", "timer", "trigger",
    "land", "atmosphere", "coord", "radio", "spot", "missionCommands",
    -- DCS object constructors / class tables
    "Unit", "Group", "StaticObject", "Airbase", "Object", "Controller",
    "Weapon", "Runway", "Warehouse", "AI", "Spot",
    -- DCS utility globals
    "dcsCommon", "mist",
    -- Optional external mods, always guarded at the call site (e.g. `if STTS and ...`)
    "STTS",
    -- Legacy MM customization global (deprecated, guarded with type() checks)
    "ctld_config_user",
    -- Lua 5.1 stdlib present in DCS but not in luacheck min std
    "require", "dofile", "loadfile", "loadstring",
    -- io / os present in DCS sandboxed environment
    "io", "os",
}

-- CTLD globals defined across src/ files (writable — they are defined here)
globals = {
    -- Core namespace
    "ctld",
    -- OOP helper (src/core/class.lua)
    "class",
    -- Config
    "CTLDConfig",
    -- i18n
    "CTLDi18n",
    -- Utils / infrastructure
    "EventDispatcher",
    "CTLDObjectRegistry",
    "CTLDTypeCollector",
    "CTLDParachuteEffect",
    "CTLDNullParachuteEffect",
    -- Domain classes
    "CTLDCrate",
    "CTLDCrateManager",
    "CTLDCrateAssemblyManager",
    "CTLDTroopGroup",
    "CTLDTroopManager",
    "CTLDVehicle",
    "CTLDVehicleSpawner",
    "CTLDFOB",
    "CTLDFOBManager",
    "CTLDBeacon",
    "CTLDBeaconManager",
    "CTLDReconRenderer",
    "CTLDReconManager",
    "CTLDZoneManager",
    "CTLDLogisticZone",
    "CTLDTroopZone",
    "CTLDSceneManager",
    "CtldScene",
    "CTLDPlayer",
    "CTLDPlayerTracker",
    "CTLDPlayerManager",
    "CTLDJTAC",
    "CTLDJTACDetector",
    "CTLDJTACMessage",
    "CTLDJTACManager",
    "CTLDSmokeManager",
    "CTLDStaticWatcher",
    "CTLDDCSEventBridge",
    "CTLDCoreManager",
}

-- Per-file overrides

-- i18n dictionaries hold translated UI strings, not code — a 200-char line limit doesn't serve
-- readability here the way it does in src/ logic, and wrapping a translation mid-sentence would
-- only make the dictionaries harder to diff/maintain.
files["src/CTLD_i18n_en.lua"] = { max_line_length = false }
files["src/CTLD_i18n_fr.lua"] = { max_line_length = false }
files["src/CTLD_i18n_es.lua"] = { max_line_length = false }
files["src/CTLD_i18n_ko.lua"] = { max_line_length = false }

files["tests/"] = {
    -- Test helpers may use additional globals. `_CTLD_assetCheck` / `_CTLD_STOCK_TYPES` come from
    -- the dev-time companion (tools/companion/, itself excluded from luacheck) exercised by its spec.
    globals = { "describe", "it", "setup", "teardown", "before_each", "after_each",
                "assert", "spy", "mock", "stub",
                "ctld_test", "_CTLD_assetCheck", "_CTLD_STOCK_TYPES" },
}
