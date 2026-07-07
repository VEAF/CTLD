# Recon system

The recon system lets players reveal **enemy** units that an allied unit can actually see. Its
scope is deliberately narrow: RECON displays only enemy assets detected via Line-of-Sight (LOS)
from an allied unit. It must never be used to show friendly assets (FOBs, zones, beacons) — those
belong to their own manager menus.

Source lives in `src/CTLD_recon.lua`, which defines two collaborators:

- `CTLDReconRenderer` — a **static table** (no instance) that draws icons on the F10 map.
- `CTLDReconManager` — the domain **singleton** (`CTLDReconManager = class()`, obtained via
  `CTLDReconManager.getInstance()`) that owns per-player state, the scan pipeline, and the RECON
  F10 submenu.

See [Architecture](../architecture.md) for the manager/singleton idiom and
[Events](../events.md) for the events listed below.

## Scan → mark pipeline

A recon session for a player runs the following loop:

1. The player enables one or more **layers** from the RECON submenu (all layers start disabled).
2. The player starts RECON. `scan()` runs an LOS check via `ctld.utils.getUnitsLOS()` and draws
   one Draw-API icon per detected target, shaped by the target's layer.
3. Auto-refresh is always enabled at start. Every `reconRefreshInterval` seconds a refresh tick
   re-scans and reconciles new / moved / lost targets.
4. Stopping RECON removes every mark and cancels the timer.

### `scan(playerUnit, player)` — start / re-scan

`scan()` is the F10 "RECON [Start]" action and is also called internally on a layer toggle while a
scan is active (a re-scan with the updated layer set). It:

- Gates on `ctld.gs("reconF10Menu")` — the same key as the menu section. If RECON is visible, scan
  works without any extra config.
- Enforces a minimum AGL altitude of `ctld.gs("reconMinAltitude")` (fallback `50` m), computed from
  `land.getHeight()` under the unit.
- Cancels any previous scan (removes its timer and marks) before rebuilding.
- Calls `_scanLOS()` with the **full** player layer list (not just the enabled ones), so
  `_matchLayer()` can enforce layer priority correctly (see below), then creates icons for the
  returned targets and counts them per layer.
- Records the session in `self._activeScans[player]`.
- Syncs FARP/FOB marks via `_syncFarpMarks()`.
- Publishes `OnReconScan`, then calls `enableAutoRefresh(..., true)` and rebuilds the RECON branch.

RECON starts even when no layer is enabled: the player can activate layers from the menu afterwards
without restarting. On a fresh start with no layers, an informational message is shown; on a
layer-toggle re-scan it is suppressed.

### `_scanLOS(playerUnit, enabledLayers, searchRadius)` — LOS core

`_scanLOS()` builds the enemy unit-name list (`_getEnemyUnitNames()` covers `GROUND`, `AIRPLANE`,
`HELICOPTER`, `SHIP` for the opposing coalition), then calls `ctld.utils.getUnitsLOS()` with an
`altoffset` of `180` (matching legacy). For every visible unit it resolves the best layer via
`_matchLayer()` and, if that layer is enabled, produces a target record carrying `unit`,
`unitName`, `unitType`, `coalition`, `playerCoalition`, `position`, `distance`, and `layer`.

### Auto-refresh: `_doRefresh(playerName, unitName, _t)`

The timer callback re-runs `_scanLOS()`, indexes the previous targets by `unitName`, and
classifies the current ones:

- **new** — no previous entry: allocate a mark, draw the icon, tag `status = "new"`.
- **moved** — same unit displaced more than `5` m: remove the old icon, allocate a **fresh** mark
  ID, redraw, tag `status = "moved"`. DCS mark IDs are never reused, so a moved target always gets a
  new ID.
- **existing** — displacement ≤ `5` m: carry the previous `markId` forward unchanged.
- **lost** — remaining in the previous index: remove the icon; the reason is `"dead"` if the unit no
  longer exists, otherwise `"out_of_los"`.

The tick updates `scan.targets`, re-syncs FARP/FOB marks, re-schedules itself, and publishes
`OnReconScanRefresh` with the full new/moved/lost breakdown.

### Stop and toggle

- `stopScan()` (F10 "RECON [Stop]") cancels the timer, removes all target marks and FARP/FOB marks,
  clears `_activeScans[player]`, and publishes `OnReconHideTargets`. Layer enabled/disabled states
  are **preserved** for the next start.
- `enableAutoRefresh()` / `disableAutoRefresh()` toggle the refresh timer and publish
  `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled`. Disabling freezes the current marks in
  place.
- `toggleLayer()` flips a layer's `enabled` flag, tells the player, and — if a scan is active —
  re-scans immediately so the new layer set takes effect. It publishes `OnReconLayerToggled`.

## Layers

Layers are defined once in `CTLDReconManager._defaultLayers` and **copied per player** by
`_getPlayerLayers()` (lazily initialised), so each player carries independent enabled/disabled
state. Each layer object has a `layerId`, display `name`, `enabled` flag, `color`, `filterAttrib`
(a DCS unit attribute name), and an `iconRenderer` key.

| `layerId` | Name | `filterAttrib` | `iconRenderer` |
| --- | --- | --- | --- |
| `infantry` | Infantry | `Infantry` | `infantry` |
| `air_defense` | Air Defense (AA) | `Air Defence` | `aa` |
| `ground_vehicles` | Ground Vehicles | `Vehicles` | `vehicle` |
| `helicopters` | Helicopters | `Helicopters` | `helicopter` |
| `aircraft` | Aircraft | `Planes` | `aircraft` |
| `ships` | Ships | `Ships` | `ship` |
| `farp_fob` | FARP / FOB | `nil` | `farp` |

**Layer order is significant.** `_matchLayer()` walks the full ordered list and returns the first
layer whose `filterAttrib` the unit has. More specific attributes must precede broader ones:
`Air Defence ⊂ Vehicles`, so `air_defense` comes before `ground_vehicles`; `Helicopters ⊂ Planes`,
so `helicopters` comes before `aircraft`. Crucially, `_matchLayer()` runs against the full list even
when scanning, then returns the matched layer only if it is currently enabled — this stops a unit
from "falling through" to a lower-priority layer when its best-match layer is off (a helicopter must
not appear as Aircraft when the Helicopters layer is off; a ZU-23 must not appear as Vehicle when AA
is off).

The `farp_fob` layer has `filterAttrib = nil` on purpose: `_matchLayer()` skips layers without a
`filterAttrib`, because FARP/FOB detection uses a dedicated pipeline rather than unit-attribute
matching.

## FARP/FOB layer lifecycle

FARP/FOB marks do not follow the target-record lifecycle. They are handled by `_syncFarpMarks()`
and tracked in `self._farpMarks[player]` (keyed by object id → mark id). Detection draws from two
sources, each gated by `reconSearchRadius` (fallback `5000` m) and a `land.isVisible()` LOS check at
+180 m:

- **Source A** — `coalition.getAirbases()` for the enemy side, filtered to objects whose
  `getDesc().attributes.Helipad` is set.
- **Source B** — enemy FOBs from `CTLDFOBManager` (`_fobs` matching the enemy coalition and alive).

New detections draw an icon, register a `CTLDStaticWatcher` under key
`"recon_farp_<player>_<id>"`, and publish `ReconFarpDetected`. When the watched object dies, the
watcher removes the icon, clears the entry, and publishes `ReconFarpLost`. Marks are **persistent**:
an already-marked object is skipped on subsequent syncs (no flicker), and marks survive until the
object dies or the layer/scan is cleared. `_clearFarpMarks()` removes every FARP/FOB mark for a
player and cancels its watchers.

## Icon rendering

`CTLDReconRenderer.createIcon(target, markId)` dispatches on `target.layer.iconRenderer` to the
matching draw function (`drawInfantryIcon`, `drawVehicleIcon`, `drawAAIcon`, `drawAircraftIcon`,
`drawHelicopterIcon`, `drawShipIcon`, `drawFarpIcon`), falling back to a plain circle for an unknown
key. Each target consumes up to three Draw-API elements at ids `markId*10+1 .. markId*10+3`;
`removeIcon(markId)` deletes all three.

Icon **shape** encodes the layer type, and icon **color** encodes the detected unit's coalition
(RED → red, BLUE → blue, NEUTRAL → grey), so the two dimensions never collide. Icon size scales with
`ctld.gs("reconIconScale")` (fallback `1.0`). Marks are drawn for the player's coalition only, and
all mark IDs come from the app-wide monotonic counter `ctld.utils.getNextMarkId()` via `_nextMark()`.

## F10 menu

`CTLDReconManager` registers a menu section at `init()` through
`CTLDPlayerManager.getInstance():registerMenuSection({ key = "recon", ..., configKey =
"reconF10Menu", order = 70 })`, gated on `reconF10Menu`. `buildMenuSection()` adds the `RECON`
submenu under `CTLD` and delegates to `_addReconCommands()`, which lays out:

- a single **RECON [Start]** / **RECON [Stop]** toggle reflecting the active-scan state;
- one command per layer, whose label shows the **next action** — `[activate]` when the layer is off,
  `[deactivate]` when on. A ` (X)` suffix is appended while RECON is idle (no active scan).

After any state change (start, stop, layer toggle) `_rebuildReconBranch()` clears the RECON branch
and re-adds the commands with fresh labels, then refreshes the menu.

## Query API

- `getActiveScan(player)` — the current scan state (`playerUnit`, `coalition`, `targets`, `layers`,
  `autoRefresh`, `refreshTimer`) or `nil`.
- `getPlayerLayers(player)` — the player's layer array (lazily initialised).

## Emitted events

| Event | When |
| --- | --- |
| `OnReconScan` | A scan starts (or re-scans) |
| `OnReconScanRefresh` | An auto-refresh tick completes |
| `OnReconHideTargets` | RECON is stopped |
| `OnReconAutoRefreshEnabled` / `OnReconAutoRefreshDisabled` | Auto-refresh toggled |
| `OnReconLayerToggled` | A layer is enabled/disabled |
| `ReconFarpDetected` / `ReconFarpLost` | A FARP/FOB mark is added / its object dies |

## Configuration keys

| Key | Fallback | Purpose |
| --- | --- | --- |
| `reconF10Menu` | — | Gate for the RECON submenu and `scan()` |
| `reconSearchRadius` | `5000` | LOS scan radius (m) |
| `reconMinAltitude` | `50` | Minimum AGL to scan (m) |
| `reconRefreshInterval` | `10` | Auto-refresh period (s) |
| `reconIconScale` | `1.0` | Icon size multiplier |

All configuration is read-only via `ctld.gs("...")` — never `config:getSetting()`.
