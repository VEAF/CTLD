# AA system assembly

`CTLDCrateAssemblyManager` (`src/CTLD_aasystem.lua`) turns several crates unpacked in
proximity into a complete air-defence system. It is a singleton obtained via
`CTLDCrateAssemblyManager.getInstance()` and covers three operations on the supported
systems — **HAWK, Patriot, NASAMS, BUK, KUB, S-300**:

- **assembly** — spawn a full system once all required part crates are packed together;
- **rearm** — add launchers to an existing complete system;
- **repair** — respawn a damaged system in place.

The manager keeps one field, `_completeSystems` (`groupName → { details, template }`),
tracking every system it has spawned so it can later count, rearm, or repair them.

## Templates

Templates are declared in `CTLD_config.lua` (inside `CTLDConfig:load()`), which overwrites
the placeholder `CTLDCrateAssemblyManager.TEMPLATES = {}` before any manager init runs.
A mission maker may override `CTLDCrateAssemblyManager.TEMPLATES` before init if needed.
Each template describes one system:

```lua
{
    name           = "HAWK AA System",   -- display name, used as the system identity
    count          = 5,                   -- unique part types required = "complete"
    side           = 2,                   -- coalition.side.* (1 = RED, 2 = BLUE)
    sectionName    = "SAM mid range",     -- spawnableCrates section to inject crate entries into
    allCratesLabel = "HAWK - All crates", -- i18n key for the auto-generated "All crates" mixedSet
    parts = {
        { DCSTypename = "Hawk ln",   desc = "HAWK Launcher",     launcher = true, weight = 1004.01 },
        { DCSTypename = "Hawk sr",   desc = "HAWK Search Radar", amount = 2,      weight = 1004.02 },
        { DCSTypename = "Hawk tr",   desc = "HAWK Track Radar",  amount = 2,      weight = 1004.03 },
        { DCSTypename = "Hawk pcp",  desc = "HAWK PCP",          NoCrate = true,  weight = 1004.04 },
        { DCSTypename = "Hawk cwar", desc = "HAWK CWAR",         amount = 2, NoCrate = true, weight = 1004.05 },
    },
    repair = { desc = "HAWK Repair", weight = 1004.06 },
}
```

Part fields:

| Field | Meaning |
| --- | --- |
| `DCSTypename` | DCS type name of the ground unit spawned at assembly (the crate descriptor's `unit`) |
| `desc` | i18n key used both for the crate menu entry and for missing-part messages |
| `weight` | crate weight; a part **without** `weight` gets no standalone crate |
| `launcher` | `true` marks the part whose crate triggers rearm detection |
| `amount` | units spawned per system (default 1; launchers default to `aaLaunchers`) |
| `NoCrate` | `true` = part always present at assembly, not counted in the auto-generated `mixedSet` |
| `cratesRequired` | crates needed for that part (read from the crate descriptor at assembly, default 1) |

`count` is the number of **unique part types** that must be alive for the system to be
considered complete; it is checked by `countComplete()` and `_rearm()`.

## Crate injection into `spawnableCrates`

`CTLDCrateAssemblyManager.injectAACrates(spawnableCrates)` is called by
`CTLDCrateManager._processSpawnableCrates()` before its main loop — at that point
`CTLDConfig:load()` has already populated `TEMPLATES`. For each template it, per
`sectionName`:

1. creates the section if it does not exist yet;
2. injects one crate entry per part that carries a `weight` (`NoCrate` parts with a weight
   still get a menu entry but are not counted in the auto-generated set);
3. auto-generates an **All crates** `mixedSet` entry from all non-`NoCrate` parts when
   `allCratesLabel` is set and more than one required part exists;
4. injects the repair crate entry, tagged with the internal flag `_repairFor = tmpl.name`
   (this is not a DCS type name).

A section may hold both manually declared crate entries and injected AA entries — this is
intentional. Do **not** add AA part entries to `spawnableCrates` by hand or they will appear
twice.

## Assembly, rearm, and repair

The M7 menu controller calls the single entry point before falling through to a standard
unpack:

```lua
local aam     = CTLDCrateAssemblyManager.getInstance()
local handled = aam:tryUnpackOrRepair(heli, crate, allCrates, radius)
-- if handled == false, the caller performs the standard unpack.
```

`tryUnpackOrRepair` resolves the template from the nearest crate's descriptor
(`getTemplateForUnit(unit, _repairFor)`). If the crate belongs to no template it returns
`false`. Otherwise it dispatches:

- `_repairFor` set → `_repair()`;
- otherwise → `_assemble()`.

**`_assemble`** first tries the rearm path when the nearest crate is the template's launcher
(`_getLauncherUnit`) and a complete system of that template exists within `_REARM_DIST`
(300 m). Otherwise it collects every on-ground crate whose type belongs to the template and
lies within the assembly radius (`radius`, default `_ASSEMBLY_DIST` = 500 m) of the reference
origin, checks completeness per part (`found >= required`), and — if the coalition system
limit allows — destroys the consumed crates and spawns the group. Missing parts produce a
per-group `Cannot build …` message listing each shortfall.

When `AASystemCrateStacking` is enabled, surplus launcher crates multiply the number of
launchers spawned (`amountFactor = found - found % required`); leftover crates below one full
multiple are kept.

**`_rearm`** captures the live positions, types, and headings of the existing complete
system, destroys it, respawns it fully rearmed at the same layout, then destroys the launcher
crate.

**`_repair`** uses the persisted `details` (positions/types/headings captured at spawn) to
respawn a damaged system in place, then destroys the repair crate. If no damaged system of
the template is within `_REARM_DIST`, it reports `Cannot repair …`.

## Spawn geometry

All parts are placed relative to the **unpacking transport**, not to the scattered crate
positions (same pattern as `CTLD_fob.lua`). `_computeOrigin(transport)` returns a reference
point 100 m at 12 o'clock of the transport; `_buildSpawnArrays()` then arranges the parts on a
circle of radius `_SPAWN_RADIUS` (50 m) around that origin, giving each template part an equal
arc segment so units do not pile up. `_spawnGroup()` builds a `Group.Category.GROUND` group
via `ctld.utils.dynAdd` (using the dynAdd `y == world Z` convention) and returns the resulting
DCS `Group`.

## System limits

`countComplete(coalitionId)` counts live systems in `_completeSystems` that still contain at
least `template.count` unique alive part types. `getAllowedCount(coalitionId)` returns the
per-coalition cap from config:

| Config key | Purpose | Default |
| --- | --- | --- |
| `aaLaunchers` | launchers spawned when a launcher part has no explicit `amount` | 3 |
| `AASystemLimitBLUE` | max complete systems for BLUE | 20 |
| `AASystemLimitRED` | max complete systems for RED | 20 |
| `AASystemCrateStacking` | surplus launcher crates add extra launchers | `false` |

Assembly is refused with an out-of-parts message when `active + 1 > allowed`.

## AI zone delivery (`isAASystem`)

AI transports can deliver a whole system without crate assembly. A dropoff resolves the
delivered type through `CTLDZoneManager` (`getTypeAt`), which tags AA templates with
`isAASystem = true` when `getTemplateByName(typeName)` matches; a mission maker requests it
through a zone's `vehicleStock`:

```lua
vehicleStock = { ["HAWK AA System"] = 1 }
```

In `CTLDCoreManager:onAILand`, when the picked entry carries `isAASystem`, the dropoff branch
calls:

```lua
CTLDCrateAssemblyManager.getInstance():spawnSystemAt(vEntry.type, pt, coa, u:getCountry())
```

`spawnSystemAt(templateName, point, coa, countryId)` resolves the template by display name,
enforces the same coalition limit, builds the circle layout around `point`, spawns the group,
records it in `_completeSystems`, and publishes `OnAASystemDeployed`.

## Events

The manager publishes to the [event bus](../events.md) through
`EventDispatcher.getInstance():publish(...)`:

| Event | When |
| --- | --- |
| `OnAASystemDeployed` | a full system is assembled (crate assembly or AI delivery) |
| `OnAASystemRearmed` | launchers are added to an existing complete system |
| `OnAASystemRepaired` | a damaged system is respawned in place |

Each payload carries `systemName`, `groupName`, `coalition`, `timestamp`, and (except AI
deployment) the `heli` unit; deployment payloads also include `position`.

## Related

- [Crates](crates.md) — crate spawn/load/unload and the M7 unpack menu that drives assembly
- [Architecture](../architecture.md) — manager/singleton idiom and the init sequence
- [Events](../events.md) — the event bus and full catalogue
