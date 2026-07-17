# Configuration

CTLD ships with sensible defaults for every parameter. You never edit the source files:
all customisation lives in a single file, **`CTLD_userConfig.lua`**, which your mission
loads with a `DO SCRIPT FILE` trigger. You only override what you want to change — anything
you leave alone keeps its default value.

This page covers the **global settings** and the **per-aircraft capabilities**
(`capabilitiesByType`). Zone lists, crate definitions, FOB scenes, the minefield and
translations each have their own page — see [Where the rest is configured](#where-the-rest-is-configured).

## How configuration works

At startup, `CTLDConfig` populates every parameter with its default. Your
`CTLD_userConfig.lua` then applies your overrides on top. Throughout the running mission,
every parameter is read through a single accessor:

```lua
ctld.gs("parameterName")   -- the only authorised read form
```

### Load order in the Mission Editor

`CTLD.lua` auto-starts with factory defaults when loaded — no config file required. If you
want to customise, add `CTLD_userConfig.lua` as the **first** trigger, before `CTLD.lua`:

| Order | Action | File | Required? |
|---|---|---|---|
| 1 | DO SCRIPT FILE | `CTLD_userConfig.lua` | Optional — only if customising |
| 2 | DO SCRIPT FILE | `CTLD.lua` | Always |

`CTLD_userConfig.lua` sets your overrides in the global environment; `CTLD.lua` reads them
during init and auto-starts CTLD. (If you need to run extra setup between loading and
starting, set `ctld.dontInitialize = true` before `CTLD.lua` loads and call
`ctld.initialize()` yourself.)

### Two ways to override

**Scalars** (booleans, numbers, strings) go in the `ctld.yamlConfigDatas` block, one
`ctld.parameterName: value` line each:

```lua
-- CTLD_userConfig.lua — only override what differs from the defaults.
ctld = ctld or {}
ctld.yamlConfigDatas = [[

ctld.enablePackingVehicles: true
ctld.maximumDistancePackableUnitsSearch: 350
ctld.numberOfTroops: 8
ctld.maximumDistanceLogistic: 300
ctld.slingLoad: true

]]
```

**Tables** (aircraft capabilities, zone lists, crate catalogues…) are assigned directly on
the config instance. Each table you assign **replaces** its default entirely:

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["capabilitiesByType"] = { --[[ ... ]] }
```

## Global settings

### System

| Parameter | Default | Description |
|---|---|---|
| `debug` | `false` | Verbose logging to `CTLD.log` (requires a non-sanitized DCS install) |
| `ctldLogPath` | `""` | Override the log file path; empty = default DCS Saved Games folder |
| `debugScreenLog` | `false` | Also echo log messages to the DCS screen via `outText` |
| `location_DMS` | `false` | Show coordinates as Degrees-Minutes-Seconds instead of Degrees-Decimal-Minutes |
| `disableAllSmoke` | `false` | Globally disable all smoke at pickup and drop-off zones |
| `modTypes` | `{}` | Non-stock (mod) DCS type names your custom config uses (crates, AA parts, troop roles). Only consulted by the optional dev-time [asset-check companion](asset-validation.md) so it does not flag them — see that page |

### Crates & slingload

| Parameter | Default | Description |
|---|---|---|
| `enableCrates` | `true` | Master switch for crate spawning and unpacking |
| `enableAllCrates` | `true` | Show the "All crates" shortcut entries in the Request Equipment menus. Set `false` to keep only individual crate entries |
| `slingLoad` | `false` | Use DCS sling-load physics instead of the virtual hover system |
| `enableHoverSlingload` | `true` | Allow crate loading by hovering above it. If `false`, crates load only via the F10 menu (`loadCrateFromMenu`) |
| `loadCrateFromMenu` | `true` | Allow crate loading via the F10 menu (useful for fixed-wing that cannot hover) |
| `enableSmokeDrop` | `true` | Enable the "Drop Smoke" F10 entry |

### Distances (metres)

| Parameter | Default | Description |
|---|---|---|
| `maximumDistanceLogistic` | `200` | Max distance from a logistics zone to load or spawn a crate |
| `maxExtractDistance` | `125` | Max distance from the vehicle to troops for extraction |
| `maximumSearchDistance` | `3000` | Max distance for deployed AI troops to search for enemies |
| `maximumDistancePackableUnitsSearch` | `200` | Max distance to search for packable vehicles |

### Troops

| Parameter | Default | Description |
|---|---|---|
| `numberOfTroops` | `10` | Default / max troop group size per transport (overridden per aircraft by `maxTroopsOnboard`) |
| `enableFastRopeInsertion` | `true` | Allow fast-rope deployment |
| `fastRopeMaximumHeight` | `18.28` | Max height (m) for fast-rope insertion (≈ 60 ft) |
| `allowRandomAiTeamPickups` | `false` | Allow AI transports to randomly pick a troop template at pickup zones. When `false`, the AI always picks the first available template for its coalition |
| `nbLimitSpawnedTroops` | `{0, 0}` | Cumulative troop cap per coalition `{RED, BLUE}` — `0` = unlimited (Lua table) |

### Infantry weight simulation

CTLD estimates each troop group's weight to check whether it fits inside a transport (see
`capabilitiesByType[type].maxTroopsOnboard` and vehicle weights). Every soldier weighs a
randomised 90–120 % of `SOLDIER_WEIGHT`, plus kit and role-specific gear.

| Parameter | Default | Description |
|---|---|---|
| `SOLDIER_WEIGHT` | `80` | Base body weight per soldier (kg) |
| `KIT_WEIGHT` | `20` | Helmet + backpack per soldier (kg) |
| `RIFLE_WEIGHT` | `5` | Standard rifleman kit (kg) |
| `MANPAD_WEIGHT` | `18` | AA soldier MANPAD tube (kg) |
| `RPG_WEIGHT` | `7.6` | AT soldier RPG + rocket (kg) |
| `MG_WEIGHT` | `10` | Machine-gunner weapon + 200-round belt (kg) |
| `MORTAR_WEIGHT` | `26` | Mortar crew tube + shells (kg) |
| `JTAC_WEIGHT` | `15` | JTAC laser + radio + binoculars (kg) |
| `CIV_WEIGHT` | `2` | Light personal items for the civilian role (kg) |

### FOB

| Parameter | Default | Description |
|---|---|---|
| `enabledFOBBuilding` | `true` | Allow FOB construction from crates |
| `troopPickupAtFOB` | `true` | Allow troop pickup at built FOBs |
| `fobMinDistanceFromZones` | `500` | Minimum distance (m) from any logistic zone at which a FOB may be deployed |
| `fobLogisticZoneRadius` | `150` | Radius (m) of the logistic zone created around a deployed FOB |
| `fobTroopPickupRadius` | `150` | Radius (m) within which troops may board at a FOB |
| `fobDestructionThreshold` | `0.5` | Fraction of scene objects destroyed before a FOB is considered lost (0.0–1.0) |
| `enableFARPRepack` | `true` | Allow players to pack a deployed FARP scene back into crates for redeployment |

!!! note
    The number of crates required to build a FOB is **not** a global setting — it comes from
    the FOB scene model (`cratesRequired`, default 3), collected within 750 m. See
    [Scenes & FOB](scenes-fob.md).

### Vehicles & packing

| Parameter | Default | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Allow vehicles to be packed back into crates |
| `groundVehicleWeights` | `{...}` | Weight (kg) per vehicle DCS type, checked against each aircraft's `maxVehicleWeight` for whole-vehicle transport (Lua table) |
| `capabilitiesByType` | `{...}` | Unified per-aircraft capability table — see [Per-aircraft capabilities](#per-aircraft-capabilities) below |

### Beacons

| Parameter | Default | Description |
|---|---|---|
| `enabledRadioBeaconDrop` | `true` | Allow beacon deployment |
| `deployedBeaconBattery` | `30` | Beacon battery life (minutes) |
| `radioSound` | `"beacon.ogg"` | Beacon sound file — **must** be added to the mission `.miz`, or beacons will not work |
| `radioSoundFC3` | `"beaconsilent.ogg"` | Silent beacon file for FC3 aircraft |

### AA systems

| Parameter | Default | Description |
|---|---|---|
| `AASystemLimitBLUE` | `20` | Max active AA systems for BLUE |
| `AASystemLimitRED` | `20` | Max active AA systems for RED |
| `AASystemCrateStacking` | `false` | Allow multiple crate sets to add extra launchers (N×crates → N×launchers) |
| `aaLaunchers` | `3` | Default number of launchers per AA system when the template does not specify |

### JTAC

| Parameter | Default | Description |
|---|---|---|
| `JTAC_LIMIT_BLUE` | `10` | Max JTAC objects BLUE may spawn (fixed quota — not refilled when a JTAC is killed) |
| `JTAC_LIMIT_RED` | `10` | Max JTAC objects RED may spawn (same) |
| `JTAC_dropEnabled` | `true` | Allow JTAC crate spawn from F10 |
| `JTAC_maxDistance` | `10000` | JTAC line-of-sight range (metres) |
| `JTAC_lock` | `"all"` | Target filter: `"vehicle"` \| `"troop"` \| `"all"` |
| `JTAC_allowStandbyMode` | `true` | Allow toggling lasing on/off |
| `JTAC_laseSpotCorrections` | `true` | Lead moving targets, accounting for wind and target speed |
| `JTAC_allow9Line` | `true` | Allow 9-line requests |
| `JTAC_allowSmokeRequest` | `true` | Allow smoke-on-target requests |
| `JTAC_smokeOn_RED` | `false` | Enable smoke marking for RED JTACs |
| `JTAC_smokeOn_BLUE` | `false` | Enable smoke marking for BLUE JTACs |
| `JTAC_smokeColour_RED` | `4` | RED JTAC smoke colour — 0=Green 1=Red 2=White 3=Orange 4=Blue |
| `JTAC_smokeColour_BLUE` | `1` | BLUE JTAC smoke colour — 0=Green 1=Red 2=White 3=Orange 4=Blue |
| `JTAC_smokeMarginOfError` | `50` | Max random placement error radius (m) for smoke |
| `JTAC_smokeOffset_x` | `0.0` | Fixed East/West offset (m) added before the random error |
| `JTAC_smokeOffset_y` | `2.0` | Fixed vertical offset (m) — keeps smoke visible above terrain |
| `JTAC_smokeOffset_z` | `0.0` | Fixed North/South offset (m) added before the random error |
| `JTAC_droneRadius` | `1000` | Fallback orbit radius (m) for drone JTACs when the crate has no `specificParams` |
| `JTAC_droneAltitude` | `4000` | Fallback orbit altitude AGL (m) for drone JTACs when the crate has no `specificParams` |

#### Pre-placed JTAC groups (auto-detection)

CTLD detects JTAC groups placed in the Mission Editor at startup. A group is recognised as a
JTAC when its **group name contains `jtac`** (case-insensitive) — for example `jtac_blue_1`,
`JTAC_Red_Forward`, `blue_jtac_drone`.

!!! warning "Naming rule (mandatory)"
    Any JTAC group placed in the Mission Editor **must** include `jtac` in its group name.
    CTLD uses the group name — not the unit type — to identify pre-placed JTACs. A group
    containing a Hummer or SKP-11 will **not** be detected unless its name contains `jtac`.
    Late-activation JTAC groups are supported and registered automatically when they activate.

### RECON

| Parameter | Default | Description |
|---|---|---|
| `reconF10Menu` | `true` | Enable the RECON F10 submenu |
| `reconEnabled` | `false` | Master switch — must be `true` for scan commands to work |
| `reconSearchRadius` | `5000` | Line-of-sight scan radius (metres) |
| `reconMinAltitude` | `50` | Minimum AGL altitude (m) required to perform a scan |
| `reconRefreshInterval` | `10` | Auto-refresh interval (seconds) |
| `reconIconScale` | `1.0` | Icon size multiplier (1.0 = default, 2.0 = double) |

### Minefield

| Parameter | Default | Description |
|---|---|---|
| `showMinefieldOnF10Map` | `true` | Draw a bounding quad on the F10 map when a minefield is deployed |
| `demineRadius` | `150` | Max distance (m) from the player to the minefield centre for the "Clear Mine Field" entry to appear |

See [Minefield](minefield.md) for deployment.

## Per-aircraft capabilities

`capabilitiesByType` is the single table that defines every per-aircraft capability. **Only
aircraft listed here receive CTLD F10 menus.** Each key is the **exact DCS type name** of the
aircraft (mods included, e.g. `"Hercules"`, `"76MD"`, `"UH-60L"`).

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["capabilitiesByType"] = {
    ["UH-1H"] = {
        cratesEnabled            = true,   -- can load/unpack crates
        troopsEnabled            = true,   -- can load/deploy infantry
        canParachuteDrop         = true,   -- enables Parachute F10 entries
        canSlingload             = true,   -- enables hover-pickup + Slingload menus
        canTransportWholeVehicle = true,   -- whole-vehicle transport
        useNativeDcsCargoSystem  = true,   -- use the DCS native cargo system for crates
        convertNativeLoadToCTLD  = true,   -- convert DCS-native cargo loads to CTLD-managed
        maxTroopsOnboard         = 8,      -- max soldiers (overrides ctld.numberOfTroops)
        maxCratesOnboard         = 1,      -- max crates carried at once
        maxWholeVehiclesOnboard  = 1,      -- max whole vehicles carried at once
        maxVehicleWeight         = 1360,   -- max whole-vehicle weight (kg) this aircraft can lift
        loadableVehiclesRED      = { "BRDM-2", "BTR_D" },
        loadableVehiclesBLUE     = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
    },
    ["C-130J-30"] = {
        cratesEnabled = true, troopsEnabled = true, canParachuteDrop = true, canSlingload = false,
        canTransportWholeVehicle = true, useNativeDcsCargoSystem = true, convertNativeLoadToCTLD = false,
        maxTroopsOnboard = 80, maxCratesOnboard = 22, maxWholeVehiclesOnboard = 2,
        maxVehicleWeight = 20000,
        loadableVehiclesRED  = { "BRDM-2", "BTR_D" },
        loadableVehiclesBLUE = { "M1045 HMMWV TOW", "M1043 HMMWV Armament", "Hummer" },
    },
    -- ... one entry per aircraft type
}
```

**Field reference:**

| Field | Type | Description |
| --- | --- | --- |
| `cratesEnabled` | bool | Can load / spawn / unpack crates |
| `troopsEnabled` | bool | Can load / deploy infantry groups |
| `canParachuteDrop` | bool | Enables the "Parachute" F10 entries |
| `canSlingload` | bool | Enables hover-pickup and "Release/Cut Slingload" menus |
| `canTransportWholeVehicle` | bool | Can load and re-deploy whole vehicles |
| `useNativeDcsCargoSystem` | bool | When `true`, CTLD spawns crates as DCS cargo objects (native cargo integration). When `false`, crates are spawned directly as static objects |
| `convertNativeLoadToCTLD` | bool | When `true`, any crate loaded through the DCS cargo UI is immediately converted to a CTLD-managed crate (destroys the DCS slot, prevents ghost crates). Set `true` for helicopters where the DCS cargo UI is exposed but CTLD parachute is needed (`UH-1H`, `CH-47Fbl1`); leave `false` for aircraft that rely on DCS native cargo for ground ops (`C-130J-30`, `76MD`, `Hercules`) |
| `maxTroopsOnboard` | number | Max soldiers this aircraft can carry (overrides `numberOfTroops`) |
| `maxCratesOnboard` | number | Max crates loaded at once (fallback: 1 for unlisted types) |
| `maxWholeVehiclesOnboard` | number | Max whole vehicles carried at once (0 = disabled) |
| `maxVehicleWeight` | number | Max whole-vehicle weight (kg) this aircraft can lift; heavier vehicles are skipped by AI auto-pickup. Omit or set `nil` for unlimited |
| `loadableVehiclesRED` | string[] | DCS type names of RED-coalition vehicles this aircraft can transport whole |
| `loadableVehiclesBLUE` | string[] | DCS type names of BLUE-coalition vehicles this aircraft can transport whole |

!!! note
    When `canTransportWholeVehicle = true` and `loadableVehiclesRED/BLUE` lists a vehicle
    type, that type appears in the **Request Equipment** F10 menu. Selecting it spawns the
    vehicle as a waiting unit near the transport (instead of a crate); the pilot then loads
    it from the cockpit. See the [Pilot guide](../pilot/index.md) for the in-cockpit flow.

Aircraft **not** listed in `capabilitiesByType` receive no CTLD menus. Assigning your own
`capabilitiesByType` table replaces the built-in one entirely, so include every aircraft you
want CTLD-capable.

## Access control

Two parameters decide which player units get CTLD F10 menus.

| Parameter | Default | Description |
|---|---|---|
| `addPlayerAircraftByType` | `true` | How CTLD selects player units that receive menus |
| `transportPilotNames` | `{...}` | Whitelist of DCS **unit names** — active when `addPlayerAircraftByType = false`, and always used for AI transports |

**`addPlayerAircraftByType = true`** (default) — any player whose aircraft type is listed in
`capabilitiesByType` automatically gets CTLD menus on entering a slot. Recommended for open
multiplayer servers.

**`addPlayerAircraftByType = false`** — only unit names explicitly listed in
`transportPilotNames` get CTLD menus. Use this to restrict CTLD to a fixed set of named slots
(e.g. a dedicated transport squadron). CTLD-capable aircraft **not** in the list join the
mission normally but have no CTLD access.

```lua
local _cfg = CTLDConfig.get()
_cfg.settings["addPlayerAircraftByType"] = false
_cfg.settings["transportPilotNames"] = {
    "transport_slot_1",
    "transport_slot_2",
    "transport_slot_3",
}
```

!!! note "AI transports"
    AI transports always use `transportPilotNames`, regardless of `addPlayerAircraftByType`.
    Add AI unit names there to enable auto-pickup / drop-off behaviour.

## Where the rest is configured

Configuration that is not global lives on dedicated pages:

| Topic | Page |
|---|---|
| Troop / logistics / extract / waypoint zones (`troopZones`, `AIZones`, `wpZones`…) | [Zone setup](zones.md) |
| FOB building and scene deployment | [Scenes & FOB](scenes-fob.md) |
| `spawnableCrates`, crate descriptors and AA templates | [Crate catalogue](crates-catalogue.md) |
| Minefield deployment | [Minefield](minefield.md) |
| Localisation and translation overrides | [Translations](translations.md) |
| v1 `ctld.*` compatibility for existing scripts | [Legacy API](legacy-api.md) |

To operate CTLD from the cockpit (the F10 menu), see the [Pilot guide](../pilot/index.md).
