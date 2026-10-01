# Crate catalogue

This page is about **what you offer pilots to spawn**: the crates, whole vehicles, AA systems,
and JTAC units a mission maker defines in configuration. Everything here is data you set once in your
configuration — most easily in [`ctld-tools`](ctld-tools.md); pilots then browse it from the F10 menu
at runtime.

The in-cockpit actions — loading, dropping, unpacking, requesting, packing — live in the Pilot
guide: [Crates](../pilot/crates.md), [Vehicles](../pilot/vehicles.md), [JTAC](../pilot/jtac.md).
Per-aircraft carry limits (which airframe can lift crates or whole vehicles, and how many) are set
in [Configuration](configuration.md) via `capabilitiesByType`.

## `spawnableCrates`

`spawnableCrates` is the master catalogue. It is a table of **named sections** (each becomes an F10
submenu), and each section holds a list of crate descriptors:

In `ctld-tools` this is the **Crates** family, edited as a table per section. In a hand-written
configuration snapshot it lives under `mm_facing`:

```yaml
mm_facing:
  spawnableCrates:
    Combat Vehicles:
    - unit: M1043 HMMWV Armament
      desc: Humvee - MG
      weight: 1000.01
      cratesRequired: 3
      side: 2
    - unit: M-1 Abrams
      desc: Heavy Tank - Abrams
      weight: 1000.05
      cratesRequired: 4
      side: 2
    Artillery:
    - unit: MLRS
      desc: MLRS
      weight: 1002.01
      cratesRequired: 3
      side: 2
```

### Descriptor fields

| Field | Type | Meaning |
|---|---|---|
| `weight` | number | **Unique** crate weight (kg). Dual role: the DCS slingload mass *and* the lookup key CTLD uses to resolve which unit to spawn at unpack. Two crates must never share a weight. |
| `desc` | string | Menu label, written as plain text. CTLD passes every `desc` through its translator at load, so a label that exists in the dictionaries appears in the pilot's language — see [Translations](translations.md). |
| `unit` | string | DCS **type name** of the unit spawned when the crate set is unpacked (e.g. `"M-1 Abrams"`). Verify against the [datamine dataset](https://github.com/Quaggles/dcs-lua-datamine). |
| `side` | number | Coalition the crate is offered to: `2` = BLUE, `1` = RED. Omit to offer to both. |
| `cratesRequired` | number | How many crates of this type must sit within 300 m of each other to unpack (default `1`). |
| `isJTAC` | bool | Marks the unit as a JTAC — see [JTAC units](#jtac-units) below. |
| `spawnAs` | string | Spawn category override for air units: `AIRPLANE` or `HELICOPTER` (used by drone JTACs). Ground vehicles need no override. In `ctld-tools` you choose `GROUND` or `AIR` and the tool writes the right one, resolved from the unit's DCS category. |
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
Each entry may carry a `size` (m): the crate's edge, used to space crates in a row beside a native-cargo
aircraft (`1.5` when absent).

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
| `maxSlingloadSpeed` | `26` | Speed (**m/s**) above which a slingloaded crate is cut loose — ≈ 94 km/h / 50 kt. Raise it if your airframe warrants a higher limit. |
| `crateSpacing` | `5` | Spacing (m) between crates spawned in a set. |
| `crateSpawnGap` | `0.5` | Gap (m) between two crates in a row beside a native-cargo aircraft (see [below](#crate-spawn-near)). |

## Whole-vehicle transport

Beyond crates, CTLD can carry **whole ground vehicles** inside capable aircraft: the C-130J-30 through the
DCS cargo bay, helicopters such as the CH-47F or the Mi-8MT through the F10 menu. What a given airframe
may carry is defined per aircraft in
[`capabilitiesByType`](configuration.md), not in a separate global list:

| `capabilitiesByType` field | Meaning |
|---|---|
| `canTransportWholeVehicle` | `true` = this airframe can load/unload whole vehicles. |
| `useNativeDcsCargoSystem` | `true` = the aircraft has a DCS native cargo system (C-130J-30, CH-47F, Mi-8MT, UH-1H, Mi-24P): CTLD follows what DCS reports on board; otherwise the F10 menu handles loading. |
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

### Native cargo by aircraft type

What each aircraft does through the **DCS cargo system**, as checked in a live mission (2026-10-01). CTLD reads
`unit:getCargosOnBoard()` of the aircraft: an item is carried exactly while DCS lists it on board.

| Aircraft | List readable | Crates | Whole vehicle through DCS | Released in flight (DCS parachute) | Converted to a CTLD crate |
|---|---|---|---|---|---|
| C-130J-30 | yes | yes (loadmaster tablet) | yes (a `CRG:<unit>` entry) | yes: crates and vehicles fall alive and are followed to the ground | no |
| Mi-8MT | yes | yes, from about 5 m away | **no** (DCS lists crates only; use the F10 menu) | not tested | no (default) |
| UH-1H | yes | yes | not applicable (no whole-vehicle carry by default) | not tested | yes (default) |
| CH-47F | not verified in game | not verified | not verified | not verified | yes (default) |
| Mi-24P | not verified in game | not verified | not verified | not verified | no (default) |
| Il-76 | AI-flown only, no native cargo | | | | |

An item that CTLD does not track (cargo created by the loadmaster tablet, editor crates of an unknown type) is
ignored. If DCS cannot give the list for a type, CTLD warns once for that type and stops watching it; it never
falls back to a geometric guess.

## Where crates spawn for a native-cargo aircraft { #crate-spawn-near }

A native-cargo aircraft loads a crate through the DCS cargo window only when the crate is within a few metres
of it. So the crates it requests (**Request Equipment**, **Pack Equipt**) appear **just clear of the hull**,
in a row, instead of at the generic distance. Each type declares this in
[`capabilitiesByType`](configuration.md):

| Field | Meaning |
|---|---|
| `crateSpawnSector` | Where the row stands: `side` (a helicopter: abeam, on a randomly chosen side), `rear` (the C-130J-30) or `front`. |
| `crateSpawnDistance` | Metres from the aircraft centre to the first crate (the hull radius at crate height plus 1.5 m). `0` or absent = the type has no value. |

A type that declares no sector and distance keeps the older rule: crates spread around the aircraft at a
distance computed from its size. Crates in a row are `crate size + crateSpawnGap` apart (default gap `0.5` m,
so they never touch); the crate size is the `size` field of its entry in `spawnableCratesModels` (`1.5` m when
absent, `1.31` m for the default `load` and `dynamic` models). A row holds as many crates as fit along the
aircraft; the next row stands one step further out. If a side is taken by another aircraft, the row flips to the
other side. Vehicles, unpacking, scenes and troops are not affected.

Default values, in metres from the aircraft centre:

| Aircraft | Sector | Distance | Status |
|---|---|---|---|
| UH-1H | `side` | 3.0 | measured in game |
| Mi-8MT | `side` | 4.0 | measured in game (a crate loads from 8 m; one at 23 m is refused) |
| C-130J-30 | `rear` | 11.3 | measured in game |
| CH-47F | `side` | 3.7 | from the collision shell only, **not verified in game** |
| Mi-24P | `side` | 5.1 | from the collision shell only, **not verified in game** |

The values come from each model's collision shell; `tools/dcs-data/derive_crate_spawn.py` recomputes them from a
DCS install (see `tools/dcs-data/README.md`).

!!! warning "Existing missions keep their embedded configuration"
    A mission embeds a complete snapshot of `CTLD_userConfig.lua`, written when it was exported. A mission
    exported before this feature has no `crateSpawnSector` or `crateSpawnDistance`, so its crates keep the
    older spawn distance. Re-opening and saving it with a ctld-tools that predates the automatic
    completion of missing keys does **not** add them: until a ctld-tools release that completes them is
    available, enter the fields yourself in the editor (capabilities of each aircraft type).

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
| `JTAC_droneRadiusNoLase` | `2000` | Orbit radius (m) while searching. |
| `JTAC_droneRadiusOnLase` | `1000` | Orbit radius (m) while lasing. |
| `JTAC_droneSpeed` | `150` | Orbit airspeed (km/h). |

Once a JTAC is deployed, everything about **operating** it — auto-lasing, laser codes, smoke,
9-line — is covered in the [Pilot JTAC guide](../pilot/jtac.md).
