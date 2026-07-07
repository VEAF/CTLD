# F10 menu system

The F10 radio menu is CTLD's primary in-mission interface: every action a transport pilot
performs — loading crates, embarking troops, requesting equipment, toggling JTAC lasing — is
issued from it. This page documents the two-layer menu engine (`ctld.Menu` and
`ctld.MenuManager`), how `CTLDPlayerManager` assembles the per-player menu from sections
contributed by each manager, how the tree is refreshed against changing flight and cargo state,
and the full menu tree as it is rendered in game.

**Source:** `src/CTLD_menu.lua` (the engine), `src/CTLD_player.lua` (ownership and section
orchestration).

## Two-layer architecture

The design separates *what the menu contains* from *how DCS renders it*. The DCS
`missionCommands.*` API is fragile — there is no way to query the current menu, no partial
update, and no automatic pagination — so CTLD keeps an authoritative in-memory tree and treats
every DCS call as a rendering side-effect of that tree.

| Layer | Class | Responsibility |
| --- | --- | --- |
| Logical model | `ctld.Menu` | In-memory tree for one group's menu. Unlimited depth; pagination is transparent to callers. One `ctld.Menu` per `groupId`. |
| DCS renderer | `ctld.MenuManager` | Singleton owning every `ctld.Menu`. Wipes and rebuilds a group's CTLD entries atomically on `refresh()`; sorts siblings by `order`; paginates. |
| Orchestrator | `CTLDPlayerManager` | Owns the F10 menu lifecycle: builds it on player-enter, assembles it from registered sections, and drives refreshes on flight/cargo state changes. |

`CTLDPlayerManager` follows the standard manager idiom (`CTLDPlayerManager = class()` +
`getInstance()`; see [Architecture](../architecture.md)). The menu engine does **not** use
`class()`: `ctld.MenuManager` is a hand-rolled singleton (`ctld.MenuManager = ctld.MenuManager or {}`,
`_instance`, `getInstance()` calling `self:_new()`), and `ctld.Menu` instances are plain tables
with a metatable created by `ctld.Menu:_new(groupId, manager)`.

```
CTLDPlayerManager                 ctld.MenuManager
  _menuSections[]           →       menus{}  (groupId → ctld.Menu)
  registerMenuSection()             refreshMenuForGroup() / deferredRefreshForGroup()
  buildMenu(playerObj)              _rebuildMenuNode() / _rebuildPagedChildren()
  refreshForUnit(unitName)          _sortByOrder()
                                  ctld.Menu
                                    addSubMenu / addCommand / clearBranch
                                    setBranchEnabled / removeMenuBranch
                                    _getNode(pathTable) / refresh()
```

## The menu model — `ctld.Menu`

A `ctld.Menu` is a tree of nodes. Callers manipulate this tree exclusively; they never call
`missionCommands.*` directly. There are two node types plus the root menu object itself.

```lua
-- Root menu (the ctld.Menu instance)
{
    groupId    = number,     -- DCS group ID this menu belongs to
    groupName  = "string",   -- resolved once at creation, for name-based lookup
    children   = { ... },    -- root-level nodes
    _lookup    = { ... },    -- "path.string" → node reference (fast access)
    manager    = reference,  -- back-reference to ctld.MenuManager
    nextItemId = number,     -- counter for unique node ids
}

-- Submenu node
{
    id       = "sub_123",
    name     = "string",
    type     = "submenu",
    children = { ... },
    order    = number|nil,   -- position among siblings (see Order convention)
    enabled  = boolean,      -- DCS visibility (see Enabled convention), default true
}

-- Command node
{
    id             = "cmd_456",
    name           = "string",
    type           = "command",
    functionToCall = function,
    anyArgument    = table,   -- passed as-is to the callback; defaults to {}
    order          = number|nil,
    enabled        = boolean, -- default true
}
```

### Order convention

Every node may carry an optional `order` field (a number). Before rendering, siblings are sorted
by `order` **ascending**, independent of insertion order or manager initialisation sequence.
Because each manager registers its section independently, without explicit `order` the visual
position of a submenu would depend on the fragile manager init order. Explicit `order` makes
positions declarative and stable. Recommended spacing is multiples of 10 (10, 20, 30 …) to leave
room for future insertions. Nodes without an `order` value are appended last (`math.huge`); ties
preserve insertion order (stable sort).

### Enabled convention

Every node carries an `enabled` field (boolean, default `true`). A disabled node
(`enabled == false`) is invisible in DCS but **remains in the memory tree, preserving its `order`
slot** — re-enabling it returns it to the exact same F-key position it would have occupied if
always visible. Toggle it with `setBranchEnabled(path, bool)` followed by `refresh()`. This is how
features are unlocked at runtime (e.g. a mission trigger enabling FOB building mid-mission)
without disturbing sibling slots.

### `_lookup` table

The `_lookup` table maps a dotted path string to a node reference, giving O(1) path resolution
instead of O(depth × siblings) tree traversal:

```lua
_lookup = {
    ["CTLD"]                          = <ref>,
    ["CTLD.Troop Commands"]           = <ref>,
    ["CTLD.Troop Commands.Infantry"]  = <ref>,
}
```

It is maintained automatically by `addSubMenu` / `addCommand` and pruned by `clearBranch`,
`removeMenuBranch`, and (indirectly) `buildMenu` when it resets the model.

## Rendering — `ctld.MenuManager`

### Atomic refresh

DCS offers no per-item update, so a refresh is all-or-nothing: the manager removes CTLD's
current top-level entries, then rebuilds the whole tree from memory. Crucially, it removes **only
CTLD's own entries** — it does *not* pass `nil` to `missionCommands.removeItemForGroup` (which
would also destroy standard DCS entries such as Ground Crew and ATC). It tracks the opaque DCS
handle returned by `addSubMenuForGroup` / `addCommandForGroup` in each top-level node's
`_dcsHandle` field and removes exactly those handles. (Passing a string path array to
`removeItemForGroup` is silently ignored by DCS, which is why the opaque handle is required.)

```
refreshMenuForGroup(groupId)
  1. Validate a menu exists in memory for groupId
  2. For each top-level child with a stored _dcsHandle:
        missionCommands.removeItemForGroup(groupId, handle); clear the handle
  3. Sort root children by order, then for each:
        _rebuildMenuNode(groupId, {}, child)   -- recursive, depth-first
  4. Return { success = true, refreshedCount = N }
```

`_rebuildMenuNode` skips disabled nodes (returns 0), renders a submenu with
`addSubMenuForGroup` (capturing the new `_dcsHandle`), renders a command with
`addCommandForGroup`, and recurses into submenu children via `_rebuildPagedChildren`.

### Debounced refresh

`ctld.Menu:refresh()` does not rebuild immediately — it calls
`ctld.MenuManager:deferredRefreshForGroup(groupId)`, which coalesces all refresh requests for a
group within a `DEBOUNCE_S = 0.15 s` window into a single DCS rebuild (scheduled via
`timer.scheduleFunction`). This prevents rapid-fire callers (the flight-state poller oscillating,
cargo detection, landing events firing together) from ejecting the player out of the F10 menu
mid-navigation. The initial `buildMenu` on player-enter also routes through the debounce.
`refreshMenuForGroup` remains available for a direct, non-debounced rebuild.

### Pagination

DCS gives each menu level ten programmer-controlled slots (F1–F10; F11 is the DCS "Previous Page",
F12 is "Quit"). `_rebuildPagedChildren` applies this rule to a pre-sorted, enabled-only list of
children:

| Visible children | Rendering |
| --- | --- |
| ≤ 10 | All rendered on one page (no pagination). |
| > 10 | F1–F9 render the first nine items; F10 = a `→ Next Page` submenu; the remainder recurse inside it. |

The `→ Next Page` node exists **only at render time** — it is never part of the memory model — and
its label is translated via `ctld.tr("→ Next Page")`. The last page always receives ≤ 10 items.
Because pagination is recomputed on every refresh, there is no cached page state to invalidate and
nesting depth is unlimited.

**Example — a submenu of 15 vehicles:**

```
F10 → Vehicles → (page 1):
  F1  vehicle_1 … F9 vehicle_9    F10  → Next Page
F10 → Vehicles → → Next Page:
  F1  vehicle_10 … F6 vehicle_15
  (F11 Previous Page — provided by DCS)
```

### Callback wrapping

When a command is rendered, its user callback is wrapped in a closure that isolates failures with
`pcall`, so one broken callback cannot crash the whole menu render:

```lua
local wrapped = function()
    local ok, err = pcall(node.functionToCall, node.anyArgument or {})
    if not ok then
        ctld.logError("ctld.MenuManager: callback failed for '%s': %s", node.name, tostring(err))
    end
end
missionCommands.addCommandForGroup(groupId, node.name, dcsPath, wrapped, {})
```

The callback receives exactly the `anyArgument` table supplied at `addCommand` time (defaulting to
`{}`); it is not augmented with the group id. Callers that need the group encode it in
`anyArgument` themselves.

## `ctld.Menu` API

All mutating methods return a status table `{ success = bool, message = string, ... }` rather than
raising errors (Lua 5.1 has no exceptions; explicit returns are more robust in the DCS
single-threaded environment).

| Method | Purpose |
| --- | --- |
| `addSubMenu(pathTable, menuName, opts)` | Add a submenu at `pathTable` (`{}` = root). `opts.order` / `opts.enabled` set position and initial visibility. **Idempotent**: if the submenu already exists it is returned unchanged (with `order`/`enabled` updated if supplied). Returns `{ success, message, subMenuId }`. |
| `addCommand(pathTable, commandName, functionToCall, anyArgument, opts)` | Add an executable command. `anyArgument` must be a table (or nil → `{}`). `opts.order` sets position. Returns `{ success, message, commandId }`. |
| `clearBranch(pathTable)` | Empty a submenu's children **without removing the container**, so its `order` slot does not shift. The standard idiom for dynamic proximity lists (nearby crates, loadable vehicles). |
| `setBranchEnabled(pathTable, enabled)` | Toggle a branch's DCS visibility while keeping it (and its `order` slot) in memory. Follow with `refresh()`. |
| `removeMenuBranch(pathTable)` | Permanently remove a branch and its descendants. Returns `{ success, message, removedCount }`. Reserved for truly permanent removals — prefer `clearBranch` / `setBranchEnabled`. |
| `refresh()` | Convenience shortcut to `manager:deferredRefreshForGroup(self.groupId)` — wipe + rebuild (ordered, paged), debounced. |

Common failure messages: `"Path not found: …"` (create the parent submenu first),
`"Cannot add submenu/command under a command node"`, `"Invalid menu name"`,
`"Invalid function reference"`, `"Cannot remove root menu"`.

The dynamic-refresh idiom, used throughout the crate/vehicle managers:

```lua
local menu = ctld.MenuManager:getInstance():getMenuByGroupId(groupId)
menu:clearBranch({ "CTLD Commands", "Pack Vehicles" })   -- keep the container, drop its contents
for _, v in ipairs(nearbyVehicles) do
    menu:addCommand({ "CTLD Commands", "Pack Vehicles" }, v.name, packFn, { unitName = v.name })
end
menu:refresh()   -- single atomic, debounced rebuild
```

## `ctld.MenuManager` API

| Method | Purpose |
| --- | --- |
| `getInstance()` | Return (create on first call) the singleton. |
| `createMenuForGroup(groupId)` | Create an empty `ctld.Menu` for a numeric `groupId`. **Idempotent**: returns the existing menu if one is already registered. Returns the menu, or `nil` on an invalid id. |
| `refreshMenuForGroup(groupId)` | Immediate, non-debounced wipe + rebuild of the group's CTLD entries. Returns `{ success, message, refreshedCount }`. |
| `deferredRefreshForGroup(groupId)` | Schedule a debounced (0.15 s) refresh; coalesces bursts. |
| `getMenuByGroupId(groupId)` | Menu for a numeric group id, or `nil`. |
| `getMenuByGroupName(groupName)` | Menu whose group name matches, or `nil`. |
| `getMenuByUnitName(unitName)` | Menu of the group containing that unit (`Unit.getByName` → group), or `nil`. |
| `getMenuByUnitId(unitId)` | Menu of the group containing that unit (`Unit.getByID` → group), or `nil`. |

Group-name resolution (`_getGroupName`) iterates the three coalitions and matches on
`group:getID()`, because `Group.getByID()` does not exist in the DCS scripting API — only
`Group.getByName()` is available.

## Section registration — `CTLDPlayerManager`

The root `CTLD` submenu and the `Check Cargo` command are added directly by `CTLDPlayerManager`.
Every other top-level section is contributed by the manager that owns it. Each manager registers
its section once, at its own `getInstance()` time:

```lua
-- e.g. from a crate/troop/jtac manager
CTLDPlayerManager.getInstance():registerMenuSection({
    key           = "crates",              -- unique id; duplicate keys are ignored (idempotent)
    manager       = _cmInstance,           -- the manager instance
    method        = "buildMenuSection",    -- called as manager:method(playerObj, menu)
    configKey     = "enableCrates",        -- ctld.gs(configKey) must be true; nil = always active
    order         = 40,                     -- lower = higher in the menu
    refreshMethod = "refreshMenuSection",  -- optional; called on land/takeoff (see below)
})
```

A `sectionDef` carries: `key`, `manager`, `method`, optional `configKey`, optional `order`, and an
optional `refreshMethod`. Registration is idempotent by `key`.

**Pre-init registration.** Scene files can be loaded before `CTLDPlayerManager.getInstance()` runs.
For that case, `CTLDPlayerManager.deferMenuSection(sectionDef)` queues a section at module
top-level; the queue is flushed into `_menuSections` during `init()`. The mine-field scene uses
this path.

### `buildMenu(playerObj)`

Called on player-enter (and re-runnable). It:

1. Gets/creates the group's `ctld.Menu` via `ctld.MenuManager:getInstance()`.
2. Resets the memory model (`children`, `_lookup`, `nextItemId`) so sections do not accumulate on
   successive calls.
3. Adds the root submenu `ctld.tr("CTLD")` at `order = 10`.
4. Adds the `Check Cargo` command under the root — it tallies loaded crates, in-transit troops,
   and whole vehicles for the transport, then `outTextForGroup`.
5. Iterates the registered sections **sorted by `order`**; for each, if `configKey` is nil or
   `ctld.gs(configKey) == true`, calls `manager:method(playerObj, menu)` to build that section's
   subtree.
6. Calls `menu:refresh()` for a single atomic render.

**Capability gating.** Player capabilities are detected in `_detectCapabilities` from
`ctld.gs("capabilitiesByType")[typeName]`: a transport is any type with an entry;
`canCarryVehicles` is set when that entry's `canTransportWholeVehicle == true`. Managers use these
flags (and their own config/proximity checks) to decide which items to render. When
`addPlayerAircraftByType == false`, only units whose name is listed in `transportPilotNames`
receive a CTLD menu at all.

`refreshForUnit(unitName)` and `refreshAll()` trigger a debounced refresh for one / every tracked
player.

## Flight-state refresh

Items whose availability depends on being airborne vs on the ground (e.g. `Release Slingload` only
in the air, `Load Crate` only on the ground) are toggled via `setBranchEnabled` / section rebuilds
rather than by re-registering DCS commands (which would leak orphaned menu items). Two mechanisms
drive this:

- **Flight-state poller (0.5 s cadence).** `S_EVENT_TAKEOFF` / `S_EVENT_LAND` fire with a 3–5 s
  delay for helicopters in DCS. A poller checks `ctld.utils.inAir(unit)` every 0.5 s and, once a
  new state holds for `DEBOUNCE_TICKS = 2` consecutive polls (~1 s), commits it and runs the full
  refresh chain — so menus switch within ~1 s of the real transition. The `onTakeoff` / `onLand`
  handlers still run when the DCS events eventually fire, but by then the state already matches and
  the refresh is a fast no-op.
- **Event/handler refreshes.** On land/takeoff (and on cargo events via the
  [event bus](../events.md) — `OnVehicleLoaded`, `OnVehicleUnloaded`, `OnCrateLoaded`,
  `OnFOBDeployed`), `CTLDPlayerManager` calls each relevant manager's refresh method
  (`refreshMenuSection`, `refreshRequestEquipmentSection`, `refreshCrateFlightSection`,
  `refreshLoadSection`, `refreshUnloadSection`, `refreshParachuteVehicleSection`,
  `refreshJtacEquipmentSection`, …). Sections that registered a `refreshMethod` are invoked
  generically through `manager:refreshMethod(playerObj)`.

| Trigger | Managers/sections refreshed |
| --- | --- |
| `S_EVENT_LAND` / poller → ground | Troop, Crate (Request Equipment, Load Crate, Unpack, flight section), Vehicle (load/unload/parachute), JTAC, plus every section's `refreshMethod` |
| `S_EVENT_TAKEOFF` / poller → air | Same set — toggles SOL/AIR branch visibility |
| Vehicle spawn/despawn | Vehicle: load section + pack section |
| Crate load/unload | Crate: flight section; Unpack section on load |
| Troop embark/disembark | Troop: menu section |
| JTAC spawn/dead | JTAC: per-JTAC command branch, for all coalition players |

## The F10 menu tree

The tree below is the full CTLD menu as rendered in game. Top-level order values determine F-key
positions; per-section visibility depends on config gates, capability gates, and proximity/state.

```
CTLD (root, order=10)
├── Check Cargo                     (command — added by CTLDPlayerManager)
├── Troop Commands                  (submenu, order=20)
├── Request Equipment               (submenu, order=25)
├── Vehicle Commands                (submenu, order=30)
├── Crate Commands                  (submenu, order=40)
├── FOB (List active FOBs)          (submenu, order=60)  ⚠ shares order with Radio Beacons
├── Radio Beacons                   (submenu, order=60)  ⚠ shares order with FOB
├── RECON                           (submenu, order=70)
├── Mine Field                      (submenu, order=75)  — conditional, ground only
├── Smoke                           (submenu, order=80)
└── JTAC                            (submenu, order=90)
```

> **`order=60` conflict.** FOB (`CTLD_fob.lua`) and Radio Beacons (`CTLD_beacon.lua`) both use
> `order=60`, so the render order between the two depends on manager init sequence. This is a known
> gap — one should be renumbered (e.g. FOB → `order=55`).

### Section registration table

| Section | Manager | Order | Config gate | Capability / state gate |
| --- | --- | --- | --- | --- |
| Check Cargo | `CTLDPlayerManager` | — | — | — |
| Troop Commands | `CTLDTroopManager` | 20 | — | `troopsEnabled = true` |
| Request Equipment | `CTLDCrateManager` | 25 | — | `cratesEnabled = true` |
| Vehicle Commands | `CTLDVehicleSpawner` | 30 | — | `canCarryVehicles = true` |
| Crate Commands | `CTLDCrateManager` | 40 | — | `cratesEnabled = true` |
| FOB (List FOBs) | `CTLDFOBManager` | **60** ⚠ | `enabledFOBBuilding` | — |
| Radio Beacons | `CTLDBeaconManager` | **60** ⚠ | `enabledRadioBeaconDrop` | `isTransport = true` |
| RECON | `CTLDReconManager` | 70 | `reconF10Menu` | — |
| Mine Field | `mineFieldScene` | 75 | — | ground + mine fields nearby |
| Smoke | `CTLDCrateManager` | 80 | `enableSmokeDrop` | `isTransport = true` |
| JTAC | `CTLDJTACManager` | 90 | `JTAC_jtacStatusF10` | — |

### Troop Commands (order=20)

Manager `CTLDTroopManager` (`src/CTLD_troop.lua`). Sub-items are gated by whether the transport is
on the ground (SOL) or airborne (AIR), whether troops are carried, and per-template conditions
(a template is offered only if `tmpl.total <= transportLimit`, stock is available, and the side
matches). `Embark / Extract` paginates at 10 items/page.

```
Troop Commands
├── Disembark Troops            [SOL — if hasTroops]
│   ├── (direct command if 1 group)
│   └── Disembark Troops (submenu if 2+ groups)
│       ├── Disembark All
│       ├── [1] TemplateNameA
│       └── [2] TemplateNameB
├── Embark / Extract Troops     [SOL — if TRZ zones or field groups nearby]
│   ├── Load from TRZ_ZoneName
│   │   ├── Load Template-Infantry
│   │   └── Load Template-Mixed
│   └── Extract from field      [if dropped troops nearby]
│       ├── GroupName1 (50m)
│       └── GroupName2 (120m)
├── Check Cargo                 [SOL]
└── Parachute Troops            [AIR — if canParachuteDrop + hasTroops]
    ├── (direct command if 1 group)
    └── Parachute Troops (submenu if 2+ groups)
        ├── Parachute All
        └── [1] TemplateNameA
```

### Request Equipment (order=25)

Manager `CTLDCrateManager` (`src/CTLD_crate.lua`). Shown when the transport is landed **and**
inside a logistics zone (LGZ). One branch per nearby logistics zone; categories paginate at
10/page.

```
Request Equipment
├── [Logistics Zone "Zone-Alpha"]
│   ├── Infantry
│   │   ├── Rifle Squad
│   │   └── Rifle Squad x3   (singleTypeSet, if enableAllCrates)
│   ├── Support
│   │   └── Machine Gunner Team
│   └── [→ Next Page]         (if > 10 categories)
└── [Logistics Zone "Zone-Beta"]
    └── [...]
```

Item conditions: JTAC items require `JTAC_dropEnabled = true`; a `descriptor.side` must match the
coalition; whole-vehicle items (Feature Q) appear when `canTransportWholeVehicle = true` and the
type is in `loadableVehiclesRED`/`loadableVehiclesBLUE`, spawning a WAITING vehicle directly rather
than a crate. Spawn types: single crate, `SingleTypeSet` (N crates of one type), `MixedSet`
(multi-type, needs `enableAllCrates`), and vehicle (Feature Q).

### Vehicle Commands (order=30)

Manager `CTLDVehicleSpawner` (`src/CTLD_vehicle.lua`). Shown when
`capabilitiesByType[typeName].canCarryVehicles = true`.

```
Vehicle Commands
├── Load / Extract Vehicles  (submenu)  [SOL — dynamic]
│   ├── M1A1 Abrams
│   ├── M113 APC
│   └── [... vehicles in range, coalition match, loadable type]
├── Unload Vehicles          (submenu)  [SOL — hidden if 0 loaded]
│   ├── Vehicle 1 (descriptor label)
│   └── Vehicle 2
└── Parachute Vehicle        (command)  [AIR — if canParachuteDrop + vehicle loaded]
```

Load filters: distance ≤ `maximumDistancePackableUnitsSearch` (~200 m), coalition match, type in
`loadableVehiclesRED`/`loadableVehiclesBLUE`, and state `WAITING`. Refreshed on landing, takeoff,
and vehicle spawn/despawn.

### Crate Commands (order=40)

Manager `CTLDCrateManager` (`src/CTLD_crate.lua`).

```
Crate Commands
├── Load Crate          (submenu, order=10) [SOL — if loadCrateFromMenu = true]
│   └── [dynamic: nearby crates < 300 m with assembly status]
├── Drop Crate(s)       (command, order=15) [SOL]
├── Unpack Crate        (submenu, order=20) [SOL]
│   ├── [Crate 1 - M1045 HMMWV TOW, 2500kg]
│   ├── [Crate 2 - Soldier]
│   └── [...]
├── List Nearby Crates  (command)           [SOL]
├── Pack Equipt         (submenu, order=25) [SOL — dynamic, rebuilt on land]
│   ├── Pack FARP-AlphaModel               [if enableFARPRepack + nearby FARP scenes]
│   ├── Pack FARP-BetaModel
│   ├── M1A1 Abrams                        [if enablePackingVehicles + packable vehicles nearby]
│   └── M113 APC
│   (submenu hidden entirely if no packable content found)
├── Parachute Crates    (command)           [AIR — if canParachuteDrop + crates onboard]
├── Release Slingload   (command)           [AIR — if canSlingload + slingload active]
└── Cut Slingload       (command)           [AIR — if canSlingload + slingload active]
```

Refresh patterns: `refreshCrateFlightSection()` toggles SOL/AIR visibility on land/takeoff;
`refreshPackEquiptSection()` rebuilds "Pack Equipt" on land; `refreshRequestEquipmentSection()`
rebuilds "Request Equipment" on zone entry/land.

### Radio Beacons (order=60)

Manager `CTLDBeaconManager` (`src/CTLD_beacon.lua`). Config gate `enabledRadioBeaconDrop = true`.

```
Radio Beacons
├── Drop Beacon              — spawns TACAN/ADF units + starts radio transmissions
├── Remove Closest Beacon    — removes a beacon within 500 m
└── List Beacons             — displays VHF/UHF/FM frequencies
```

### RECON (order=70)

Manager `CTLDReconManager` (`src/CTLD_recon.lua`). Config gate `reconF10Menu = true`.

```
RECON
├── RECON [Start] / RECON [Stop]     (toggle command)
├── Infantry        [activate/deactivate (X)]
├── Air Defense (AA) [activate/deactivate (X)]
├── Ground Vehicles [activate/deactivate (X)]
├── Helicopters     [activate/deactivate (X)]
├── Aircraft        [activate/deactivate (X)]
├── Ships           [activate/deactivate (X)]
└── FARP / FOB      [activate/deactivate (X)]
```

Label logic: RECON active + layer enabled → `[deactivate]`; RECON active + layer disabled →
`[activate]`; RECON inactive + layer disabled → `[activate] (X)`, where `(X)` marks that the scan
is not running. The seven layers are `infantry`, `air_defense`, `ground_vehicles`, `helicopters`,
`aircraft`, `ships`, `farp_fob`. Scan pipeline: altitude check (AGL ≥ `reconMinAltitude`, default
50 m) → line-of-sight per enemy unit matched against enabled layers → draw an F10-map mark per
target (shape by layer, colour by coalition) → auto-refresh timer (`reconRefreshInterval`, default
10 s) detecting new/moved/lost targets.

### Mine Field (order=75)

Manager `mineFieldScene` (`src/scenes/CTLD_mineFieldScene.lua`), registered via
`CTLDPlayerManager.deferMenuSection()`. Shown only when the player is on the ground and mine fields
are within `demineRadius` (default 150 m); hidden entirely otherwise. Refreshed on land/takeoff and
after each clearing operation.

```
Mine Field
├── Clear Mine Field (N mines, ~Xm)    [one entry per nearby mine set]
└── [...]
```

### Smoke (order=80)

Manager `CTLDCrateManager` (`src/CTLD_crate.lua`). Config gate `enableSmokeDrop = true`.

```
Smoke
├── Drop Red Smoke
├── Drop Blue Smoke
├── Drop Orange Smoke
├── Drop Green Smoke
└── Smoke Auto-Resume [activate] / [deactivate]   (toggle command)
```

With `Smoke Auto-Resume` activated, smoke markers are re-dropped automatically after burning out.

### JTAC (order=90)

Manager `CTLDJTACManager` (`src/CTLD_jtac.lua`). Config gate `JTAC_jtacStatusF10 = true`.

```
JTAC
├── Request JTAC Equipment  (submenu)  [SOL — if JTAC_dropEnabled + in LGZ]
│   ├── Air JTAC Type1    (drone, spawnAs = "AIRPLANE")
│   ├── Ground JTAC Type2 (vehicle)
│   └── [...]
├── JTAC Status  (command)
├── [JTAC Name 1]  (submenu — per active JTAC, same coalition)
│   ├── Lasing [activate] / [deactivate]        [if JTAC_allowStandbyMode]
│   ├── Spot Corrections [activate/deactivate]  [if JTAC_laseSpotCorrections ≠ nil]
│   ├── Request Smoke on Target                 [if JTAC_allowSmokeRequest]
│   └── Request 9-Line                          [if JTAC_allow9Line]
└── [JTAC Name 2]
    └── [...]
```

A per-JTAC submenu is present in every state except `DEAD` (SPAWNED, IDLE, LASING, ORBITING,
IN_TRANSIT all show it; DEAD removes it). `toggleStandby()` / `toggleSpotCorrections()` call
`_rebuildJTACCommandBranch()`, wiping and rebuilding the per-JTAC submenu for all coalition
players. Menu-affecting config flags:

| Flag | Effect on menu |
| --- | --- |
| `JTAC_dropEnabled` | Shows/hides "Request JTAC Equipment" |
| `JTAC_allowStandbyMode` | Shows/hides "Lasing [toggle]" |
| `JTAC_laseSpotCorrections` | Shows/hides "Spot Corrections [toggle]" |
| `JTAC_allowSmokeRequest` | Shows/hides "Request Smoke on Target" |
| `JTAC_allow9Line` | Shows/hides "Request 9-Line" |

## Adding a menu section to a new module

1. In your manager's `getInstance()` (or, for a scene loaded early, at module top-level via
   `CTLDPlayerManager.deferMenuSection`), call
   `CTLDPlayerManager.getInstance():registerMenuSection(sectionDef)` with a unique `key`, your
   `manager` instance, the `method` name, and an `order`. Add a `configKey` if the section is
   config-gated, and a `refreshMethod` if it needs land/takeoff refreshing.
2. Implement `Manager:buildMenuSection(playerObj, menu)` — build your subtree with
   `menu:addSubMenu` / `menu:addCommand`, assigning `order` to control position.
3. Implement `Manager:refreshMenuSection(playerObj)` (or your registered `refreshMethod`) — update
   dynamic content via `clearBranch` + re-add, or toggle visibility with `setBranchEnabled`. Do not
   re-register DCS commands directly.
4. Trigger `CTLDPlayerManager.getInstance():refreshForUnit(unitName)` on any state change that
   affects your section's visibility.

## DCS API constraints and limits

- **No menu listing API** — DCS cannot report existing menu items; the in-memory tree is the sole
  source of truth, validated locally before any DCS call.
- **All-or-nothing refresh** — no single-item update; accumulate changes, then apply one
  `refresh()`.
- **Manual pagination** — DCS does not auto-paginate; `_rebuildPagedChildren` handles it.
- **No callback introspection** — Lua function signatures cannot be validated at runtime; the
  expected signature is documented and failures are isolated with `pcall`.
- **`Group.getByID()` is unavailable** — group ids are resolved to names by iterating coalitions.

| Limit | Value |
| --- | --- |
| Programmer slots per menu level | 10 (F1–F10; F11 = Previous Page, F12 = Quit, both DCS) |
| Visible children before pagination | 10 |
| Menu depth | Unlimited (keep < 5 levels for usability) |
| Simultaneous menus | Unlimited (one per group) |
| Refresh frequency | Debounced at 0.15 s; keep well under 1 refresh/s per group |

## Design decisions

- **In-memory tree before DCS apply** — enables atomic, all-or-nothing rebuilds and keeps the model
  authoritative.
- **Pagination recomputed on every refresh** — no cached page state to invalidate; dynamic updates
  stay simple.
- **Explicit `order` + `enabled`** — positions are declarative and stable regardless of init order,
  and features can be hidden without losing their slot.
- **Debounced refresh** — absorbs bursts so players are not ejected from the menu mid-navigation.
- **Status tables, not exceptions** — Lua 5.1 has no exception handling; `{ success, message }`
  returns are more robust in a single-threaded engine.

## Differences from v1

| v1 (`old/CTLD_menus.lua`) | v2 |
| --- | --- |
| One monolithic `addTransportF10MenuOptions()` | Each manager registers its own section via `registerMenuSection` |
| Global functions (`ctld.checkTroopStatus`, `ctld.loadTroopsFromZone`, …) | OOP methods on manager instances |
| Static menu built once on player enter | Dynamic sections rebuilt on land/takeoff and cargo events |
| No order control | Explicit `order` field per node |
| PKZ / EXZ zone naming | TRZ zone naming (see the troop-zone documentation) |
| No whole-vehicle menu integration | Feature Q: whole vehicles offered in Request Equipment |

## Related subsystems

- [Player tracking](players.md) — the `CTLDPlayer` entity and `CTLDPlayerManager` lifecycle that
  owns this menu.
- [Events](../events.md) — the cargo/FOB events that drive menu refreshes.
- [Architecture](../architecture.md) — the manager/singleton idiom used by `CTLDPlayerManager`.
