# Crate catalogue

This page is about **what you offer pilots to spawn**: the crates, whole vehicles, AA systems,
and JTAC units a mission maker defines in configuration. Everything here is data you set once in
`CTLD_userConfig.lua`; pilots then browse it from the F10 menu at runtime.

The in-cockpit actions — loading, dropping, unpacking, requesting, packing — live in the Pilot
guide: [Crates](../pilot/crates.md), [Vehicles](../pilot/vehicles.md), [JTAC](../pilot/jtac.md).
Per-aircraft carry limits (which airframe can lift crates or whole vehicles, and how many) are set
in [Configuration](configuration.md) via `capabilitiesByType`.

## `spawnableCrates`

`spawnableCrates` is the master catalogue. It is a table of **named sections** (each becomes an F10
submenu), and each section holds a list of crate descriptors:

```lua
_cfg.settings["spawnableCrates"] = {
    ["Combat Vehicles"] = {
        { weight = 1000.01, desc = ctld.tr("Humvee - MG"),  unit = "M1043 HMMWV Armament", side = 2, cratesRequired = 3 },
        { weight = 1000.05, desc = ctld.tr("Heavy Tank - Abrams"), unit = "M-1 Abrams",     side = 2, cratesRequired = 4 },
    },
    ["Artillery"] = {
        { weight = 1002.01, desc = ctld.tr("MLRS"), unit = "MLRS", side = 2, cratesRequired = 3 },
    },
}
```

### Descriptor fields

| Field | Type | Meaning |
|---|---|---|
| `weight` | number | **Unique** crate weight (kg). Dual role: the DCS slingload mass *and* the lookup key CTLD uses to resolve which unit to spawn at unpack. Two crates must never share a weight. |
| `desc` | string | Menu label. Wrap in `ctld.tr(...)` for translation. |
| `unit` | string | DCS **type name** of the unit spawned when the crate set is unpacked (e.g. `"M-1 Abrams"`). Verify against the [datamine dataset](https://github.com/Quaggles/dcs-lua-datamine). |
| `side` | number | Coalition the crate is offered to: `2` = BLUE, `1` = RED. Omit to offer to both. |
| `cratesRequired` | number | How many crates of this type must sit within 300 m of each other to unpack (default `1`). |
| `isJTAC` | bool | Marks the unit as a JTAC — see [JTAC units](#jtac-units) below. |
| `spawnAs` | string | Spawn category override for air units: `"AIRPLANE"` or `"HELICOPTER"` (used by drone JTACs). Ground vehicles need no override. |
| `specificParams` | table | Extra per-unit parameters (e.g. drone `speed`, `alti`, orbit radii). |
| `mixedSet` | array | Alternative to `weight`: an entry whose value is a list of weights defines a **combined set** — one menu item that spawns several different crate types at once (see below). |

### Single crates vs sets

- A descriptor with a **`weight`** is a *single crate type*.
- When `cratesRequired > 1` and `enableAllCrates` is `true` (default), CTLD auto-generates an
  **"All crates"** shortcut that spawns the full set of identical crates in one action. Suppress it
  per-entry with `showSets = false`.
- A descriptor with a **`mixedSet`** (a list of weights) spawns a *mix* of different crate types in
  one action. Every weight it references must resolve to a single-crate descriptor **in the same
  section**, or the set is dropped at startup with a mission warning.

### Crate visual models

`spawnableCratesModels` defines the DCS static shapes crates use (`load`, `sling`, `dynamic`).
You rarely need to touch it; leave the defaults unless you want a different cargo appearance.

### Default catalogue (out of the box)

| Section | Contents |
|---|---|
| `Combat Vehicles` | Humvee MG/TOW, MRAP, LAV-25, M-1 Abrams (BLUE); BTR-D, BRDM-2 (RED) |
| `Support` | Hummer JTAC, ammo/tanker trucks (BLUE); SKP-11 JTAC, ammo trucks (RED); EWR Radar (both). FOB/FARP scene crates are auto-injected here. |
| `Artillery` | MLRS, SpGH DANA, T155 Firtina, M-109 (BLUE); 2S19 Msta (RED) |
| `SAM short range` | Avenger, Chaparral, Roland, Gepard, C-RAM (BLUE); Osa, Strela-1/10, Tor, Tunguska (RED) |
| `SAM mid range` | *Auto-injected* AA system crates: HAWK, NASAMS (BLUE), BUK, KUB (RED) |
| `SAM long range` | *Auto-injected* AA system crates: Patriot (BLUE), S-300 (RED) |
| `Drone` | MQ-9 Reaper JTAC (BLUE), RQ-1A Predator JTAC (RED) |

### Crate system settings

| Parameter | Default | Description |
|---|---|---|
| `enableCrates` | `true` | Master switch for the crate system. |
| `enableAllCrates` | `true` | Generate the "All crates" shortcut entries. |
| `maximumDistanceLogistic` | `200` | Max distance (m) from a logistics unit to spawn/load. |
| `loadCrateFromMenu` | `true` | Allow loading a crate from the F10 menu (in addition to hover pickup). |
| `enableHoverSlingload` | `true` | Allow hover-based crate pickup. |
| `hoverTime` | `10` | Seconds to hold a hover to hook a crate. |
| `minimumHoverHeight` / `maximumHoverHeight` | `7.5` / `12.0` | Hover window (m) for pickup. |
| `maxDistanceFromCrate` | `5.5` | Max horizontal distance (m) to a crate during hover pickup. |
| `maxSlingloadSpeed` | `50` | Speed (m/s) above which a slingloaded crate is lost. |
| `crateSpacing` | `5` | Spacing (m) between crates spawned in a set. |

## Whole-vehicle transport

Beyond crates, CTLD can carry **whole ground vehicles** inside capable aircraft (C-130, Il-76,
CH-47, UH-1H…). What a given airframe may carry is defined per aircraft in
[`capabilitiesByType`](configuration.md), not in a separate global list:

| `capabilitiesByType` field | Meaning |
|---|---|
| `canTransportWholeVehicle` | `true` = this airframe can load/unload whole vehicles. |
| `useNativeDcsCargoSystem` | `true` = use the DCS native cargo bay (C-130, Il-76, CH-47…); otherwise the F10 menu handles loading. |
| `maxWholeVehiclesOnboard` | Max whole vehicles held at once (`0` = no vehicle transport). |
| `maxVehicleWeight` | Max liftable vehicle mass (kg). |
| `loadableVehiclesBLUE` / `loadableVehiclesRED` | The DCS type names this airframe may carry whole, per coalition. |
| `convertNativeLoadToCTLD` | `true` = convert a DCS-native cargo load to CTLD-managed on load (e.g. UH-1H, CH-47, where the DCS cargo UI would leave ghost crates). |

For example, the default UH-1H may lift one of `M1045 HMMWV TOW`, `M1043 HMMWV Armament`, or
`Hummer` (BLUE), or `BRDM-2` / `BTR_D` (RED), up to `maxVehicleWeight = 1360` kg.

Any aircraft **not** flagged `canTransportWholeVehicle` must move vehicles as crates instead: a
pilot packs the vehicle into crates, transports them, and unpacks at the destination.

### Vehicle packing settings

| Parameter | Default | Description |
|---|---|---|
| `enablePackingVehicles` | `true` | Allow pilots to pack a ground vehicle back into crates. |
| `maximumDistancePackableUnitsSearch` | `200` | Max distance (m) from the transport to find a packable vehicle. |

The reverse operation — [packing](../pilot/vehicles.md) a vehicle back into crates — spawns
`cratesRequired` crates of the vehicle's crate type around the aircraft. There is no separate
"packable vehicles" list: any vehicle whose DCS type matches a `spawnableCrates` descriptor `unit`
is packable.

## AA systems

AA systems are **multi-crate kits**: a mission maker declares the system once in
`CTLDCrateAssemblyManager.TEMPLATES`, and CTLD automatically injects the matching part crates and
an "All crates" set into `spawnableCrates` at startup. **Do not** hand-add AA part entries to
`spawnableCrates` — they would appear twice.

A template looks like this:

```lua
CTLDCrateAssemblyManager.TEMPLATES = {
    {
        name           = "HAWK AA System",   -- display name in messages/events
        count          = 5,                    -- unique part types required for a complete system
        side           = 2,                    -- 2 = BLUE, 1 = RED
        sectionName    = "SAM mid range",      -- spawnableCrates section to inject into
        allCratesLabel = "HAWK - All crates",  -- label for the auto-generated combined set (optional)
        parts = {
            { DCSTypename = "Hawk ln", desc = "HAWK Launcher",     launcher = true, weight = 1004.01 },
            { DCSTypename = "Hawk sr", desc = "HAWK Search Radar", amount = 2,      weight = 1004.02 },
            { DCSTypename = "Hawk tr", desc = "HAWK Track Radar",  amount = 2,      weight = 1004.03 },
            { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",  NoCrate = true, weight = 1004.04 },
            { DCSTypename = "Hawk cwar", desc = "HAWK CWAR", NoCrate = true, amount = 2, weight = 1004.05 },
        },
        repair = { desc = "HAWK Repair", weight = 1004.06 },
    },
    -- more systems...
}
```

### Part fields

| Field | Meaning |
|---|---|
| `DCSTypename` | DCS type name of the ground unit spawned at assembly. |
| `desc` | i18n key used for the crate menu label *and* the "Missing X" assembly message. |
| `weight` | Unique crate weight (kg) — same dual role as any crate. **Omit** for a `NoCrate` part with no standalone crate. |
| `launcher` | `true` marks the part that triggers rearm detection. |
| `amount` | Units of this part spawned per system (default `1`; launchers default to `aaLaunchers`). |
| `NoCrate` | `true` = the part is always spawned at assembly and is **not** counted in the "All crates" set. It may still carry a `weight` to be spawnable as a standalone crate. |
| `cratesRequired` | Crates of this part type needed to unlock it (default `1`). |
| `repair` | A separate repair crate (`desc` + unique `weight`) that respawns a damaged system at full health. |

`count` is how many **unique part types** must be present for the system to be considered complete.

### Built-in AA templates

| System | Side | `count` | Section | Crate parts (bring these) | `NoCrate` parts (auto at assembly) |
|---|---|---|---|---|---|
| HAWK AA System | BLUE | 5 | `SAM mid range` | Launcher, Search Radar ×2, Track Radar ×2 | PCP, CWAR ×2 |
| NASAMS AA System | BLUE | 3 | `SAM mid range` | Launcher 120C, Search/Track Radar, Command Post | — |
| BUK AA System | RED | 3 | `SAM mid range` | Launcher, Search Radar, CC Radar | — |
| KUB AA System | RED | 2 | `SAM mid range` | Launcher, Radar | — |
| Patriot AA System | BLUE | 4 | `SAM long range` | Launcher ×8, Radar ×2, ECS | AMG |
| S-300 AA System | RED | 6 | `SAM long range` | TEL C (launcher), Flap Lid-A TR, Clam Shell SR, Big Bird SR, C2 | TEL D ×2 |

Each template also injects a **repair crate** into its section.

### AA settings

| Parameter | Default | Description |
|---|---|---|
| `AASystemLimitBLUE` | `20` | Max simultaneous complete AA systems for BLUE. |
| `AASystemLimitRED` | `20` | Max simultaneous complete AA systems for RED. |
| `AASystemCrateStacking` | `false` | Allow extra crate sets to add launchers to an existing system. |
| `aaLaunchers` | `3` | Launchers added per system when a part has no explicit `amount`. |

## JTAC units

A JTAC is just a crate descriptor flagged **`isJTAC = true`** — there is no separate JTAC type
list. Any unit (vehicle or drone) can be a JTAC:

```lua
-- ground JTAC
{ weight = 1001.01, desc = ctld.tr("Hummer - JTAC"), unit = "Hummer", side = 2, cratesRequired = 2, isJTAC = true },
-- drone JTAC
{
    weight = 1006.01, desc = ctld.tr("MQ-9 Repear - JTAC"), unit = "MQ-9 Reaper", side = 2,
    isJTAC = true, spawnAs = "AIRPLANE",
    specificParams = { speed = 150, alti = 3000, orbitRadiusNoLase = 2000, orbitRadiusOnLase = 1000 },
},
```

The **Request JTAC Equipment** F10 submenu is auto-populated from every `isJTAC = true` descriptor
available to the player's coalition — you do not maintain a second table. The submenu only appears
when `JTAC_dropEnabled ≠ false`, the aircraft is a transport, and at least one JTAC descriptor
exists for that coalition. Defaults ship a Hummer (BLUE) and SKP-11 (RED) in `Support`, plus MQ-9
Reaper (BLUE) and RQ-1A Predator (RED) in `Drone`.

### JTAC settings

| Parameter | Default | Description |
|---|---|---|
| `JTAC_dropEnabled` | `true` | Enable JTAC crate spawn from F10; also gates the visibility of JTAC descriptors. |
| `JTAC_LIMIT_BLUE` | `10` | Max JTAC objects BLUE may spawn (definitive — not refilled on death). |
| `JTAC_LIMIT_RED` | `10` | Max JTAC objects RED may spawn (same). |
| `JTAC_maxDistance` | `10000` | JTAC line-of-sight scan range (m). |
| `JTAC_lock` | `"all"` | Target filter: `"vehicle"`, `"troop"`, or `"all"`. |
| `JTAC_allowStandbyMode` | `true` | Allow pilots to toggle the laser on/off. |
| `JTAC_allow9Line` | `true` | Enable the 9-line CAS request display. |
| `JTAC_targetDeconfliction` | `true` | Prevent multiple JTACs from lasing the same target simultaneously. |
| `JTAC_droneRadius` | `1000` | Fallback orbit radius (m) when a drone descriptor has no `specificParams`. |

Once a JTAC is deployed, everything about **operating** it — auto-lasing, laser codes, smoke,
9-line — is covered in the [Pilot JTAC guide](../pilot/jtac.md).
