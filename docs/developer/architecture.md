# Architecture

## Repository structure

```
src/                    Source modules (pure Lua 5.1, one class per file)
  core/                 Foundations: class.lua, CTLD_objectRegistry, CTLD_modValidator,
                        CTLDParachuteEffect
  scenes/               Scene data files (auto-registered at load time)
  legacy/               Legacy v1 API wrappers (thin delegates, deprecated)
  CTLD_*.lua            Domain managers (config, i18n, utils, menu, zone, troop, crate,
                        vehicle, fob, aasystem, beacon, recon, jtac, player, core…)
  CTLD_userConfig.lua   User configuration (merged last)
tools/
  build/                Build tooling: merge_CTLD.ps1, listToMerge.txt, generate_i18n_dicts.ps1
tests/
  ci/                   busted tests (no DCS required)
    helpers/            DCS stubs + module loader (init.lua, loader.lua)
    unit/               *_spec.lua unit tests
    functional/         *_spec.lua functional tests
  dcs/                  DCS integration-test scenarios (require a live mission)
docs/                   Published documentation (this site)
assets/                 Runtime audio (beacon.ogg)
missions/               Demo and test .miz files
migration/
  source/               Reference — original monolithic v1 CTLD.lua (read-only, immutable)
CTLD.lua                Generated deliverable — never hand-edit (rebuilt from src/)
```

## Manager / singleton idiom

Classes are built with the minimal OOP micro-framework in `src/core/class.lua`:

```lua
MyClass = class()            -- create a class
Child   = class(MyClass)     -- subclass (single inheritance)

function MyClass:init(...) end   -- constructor, called by :new()
local obj = MyClass:new(...)     -- allocate instance + run init()
```

`class(base)` sets the class table as its own `__index`, so instance method lookups fall through
to the class; passing a `base` chains `__index` to the parent.

Domain managers are **singletons**. They declare `_instance` and expose a `getInstance()` factory
that bypasses `:new()` and calls `init()` on first access:

```lua
CTLDZoneManager = class()
CTLDZoneManager._instance = nil

function CTLDZoneManager.getInstance()
    if not CTLDZoneManager._instance then
        local o = setmetatable({}, CTLDZoneManager)
        o:init()
        CTLDZoneManager._instance = o
    end
    return CTLDZoneManager._instance
end
```

Configuration is read-only via `ctld.gs("paramName")` — never `config:getSetting()`.

## `CTLDCoreManager` init sequence

`CTLDCoreManager:init()` runs once at mission start and executes these phases in order:

| Phase | Method | Description |
| --- | --- | --- |
| INIT-B | `_initMMCrates()` | Scan coalition statics for MM-placed cargo objects |
| INIT-C | `_initMMJTACs()` | Scan coalition groups for MM-placed JTAC groups |
| INIT-D | `CTLDVehicleSpawner:scanMMVehicles()` | Scan coalition ground groups for MM-placed vehicles |
| INIT-E | `_initExtractableGroups()` | Register `extractableGroups` names into `CTLDTroopManager._droppedGroups` |
| INIT-A | `_initAITransports()` | Build AI team lists and start the auto-pickup/dropoff loop |

**INIT-E detail:** reads `ctld.gs("extractableGroups")`, calls `Group.getByName()` for each entry,
and inserts the group name into `CTLDTroopManager._droppedGroups[coalition]`. Groups not found are
logged as `WARN` and skipped. There is no late activation (iso-legacy) and no `_droppedTemplates`
entry — `embarkFromField` uses a 130 kg/unit fallback.

## Adding a new module

1. Create `src/CTLD_mymodule.lua` using the class/singleton idiom above (`CTLDMyManager = class()`,
   `_instance`, `getInstance()`).
2. Add the filename to `tools/build/listToMerge.txt` in dependency order (foundations first,
   then domain managers, then scenes, then `CTLD_core.lua`, then `legacy/`, `CTLD_userConfig.lua`
   last).
3. Add the same `dofile` entry to `tests/ci/helpers/loader.lua`.
4. Write busted specs in `tests/ci/unit/mymodule_spec.lua` (test-first — see
   [Building & testing](building-and-testing.md)).

The merge order in `listToMerge.txt` is authoritative: scenes are listed after all managers so that
`model.crate` auto-injection resolves, and `CTLD_core.lua` (the orchestrator) comes after the
scenes it instantiates.

## Internal libraries

### `core/class.lua` — OOP base

The single-inheritance class system used throughout CTLD (see the idiom above). `class()` creates a
class whose `__index` is itself; `class(base)` chains to a parent.

### `core/CTLD_objectRegistry.lua` — spawn descriptor store

`CTLDObjectRegistry` is a static registry mapping template keys to DCS group/unit spawn
descriptors. It manages **descriptors**, not instances.

```lua
CTLDObjectRegistry.register(key, descriptor)    -- add a template
CTLDObjectRegistry.spawnObject(key, coa, country, x, z, hdg, opts)
    -- → DCS Group object | nil
```

Scenes register their component descriptors at dofile time; troop and vehicle templates are
registered by their managers at init.

### `core/CTLD_modValidator.lua` — mod presence probe

`CTLDModValidator` probes whether optional DCS mods (HAWK, Patriot, NASAMS…) are present by
attempting a `coalition.addStaticObject` with the mod's unit type and immediately destroying it.

```lua
CTLDModValidator.getInstance():isPresent("AAA_HAWK_SR")  -- → bool (cached after first probe)
```

Results are cached in `_cache[typeName]`. The probe is deferred to first use so mission load time
is not impacted.

#### `probeSkip` — heliport-type objects cannot be probed

The probe technique works for `STATIC` and `GROUND` objects. It does **not** work for objects
registered with `category = "Heliports"` (spawned via the airbase API rather than the static object
API).

**Root cause (verified by live DCS diagnostic):** when a heliport-type static is spawned via
`coalition.addStaticObject`, DCS registers it as an `Airbase` entry regardless of whether the mod is
installed. All API fields — `getTypeName()`, `getCategory()`, `getCategoryEx()`, `getCallsign()`,
`getDesc().life`, `getDesc().displayName` — return identical values whether the mod is present or
absent. There is no signal in the Lua scripting API to distinguish the two states.

**Consequence:** if a heliport registry entry does not set `probeSkip = true`, `CTLDModValidator`
always reports it as present — a false-positive "mod found" even when the mod is missing.

**Rule:** any registry entry with `category = "Heliports"` **must** set `probeSkip = true`.

```lua
CTLDObjectRegistry.registerIfAbsent("Farp_FG_Petit_Helipad", {
    groupType = "STATIC",
    category  = "Heliports",
    -- probeSkip suppresses the ModValidator probe: DCS returns life=0 and identical
    -- API data regardless of mod installation state — no reliable detection is possible.
    probeSkip = true,
    -- …
})
```

**Mitigation for scenes using heliport mods:** declare `requiresMod` on the scene model.
`CTLDSceneManager:_auditAfterModValidator()` emits a `WARN` `outText` at mission start reminding the
mission maker that all clients must have the mod installed:

```lua
metalFarpScene.requiresMod = "Farp_FG_Petit_Helipad"
```

This `WARN` is the only mechanism available — automatic menu suppression is not possible for
heliport-type mods.

### `core/CTLDParachuteEffect.lua`

Visual parachute effect helper used when dropping crates/troops from altitude.

### `CTLD_utils.lua` — utility functions

Key functions available as `ctld.utils.*`:

| Function | Purpose |
| --- | --- |
| `log(level, fmt, ...)` | Write to `CTLD.log` (levels: DEBUG, INFO, WARN, ERROR) |
| `getDistance(caller, p1, p2)` | 2D ground distance between two `{x,z}` points |
| `getHeadingInRadians(caller, unit, magnetic)` | Unit heading in radians |
| `inAir(unit)` | True if unit is airborne (AGL + velocity guard) |
| `getNextMarkId()` | Allocate the next unique DCS mark ID from `ctld._markIdCounter` |
| `getNextUniqId()` | Allocate the next unique entity ID from `ctld.utils.UniqIdCounter` |
| `drawQuad(coalitionId, pts, msg)` | Draw a 4-point polygon on the F10 map |
| `buildWP(caller, pt, type, speed)` | Build a DCS waypoint table |
| `getSecureDistanceFromUnit(unitName)` | Minimum spawn clearance radius from a unit's bbox |
| `dynAddStatic(coalitionId, data)` | `coalition.addStaticObject` wrapper with country resolution |
