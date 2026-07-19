Status: ⬜ ready

# FIX-PLUGIN-CRATE-INSTANT-REFRESH — Immediate Request Equipment refresh on post-init scene crate injection

## Problem Statement

When a mission maker loads a scene plugin after CTLD (via a second DO SCRIPT FILE trigger),
the plugin's crate appears in `CTLDCrateManager._processedCrates` immediately — but the
player's Request Equipment menu does not reflect it until the next LGZ ground-position poll
tick, which fires every 10 seconds. A player who opens the menu before that first tick sees
no trace of the plugin crate, which looks like the plugin failed to load.

The 10-second delay was the residual symptom after FIX-LGZ-POLL-NIL-ISFLYING (PR #37)
corrected the poll guard (`== false` → `~= true`). PR #37 is a prerequisite; this lot
eliminates the remaining delay.

## Solution

When `_injectSceneCrate` successfully inserts a new crate into `_processedCrates`, it
immediately refreshes the Request Equipment submenu for every active transport player.
`refreshRequestEquipmentSection` already handles flight state internally (players in the
air see "Land near logistics to request equipment"), so calling it unconditionally for all
transports is safe.

From the player's perspective: the plugin crate is visible in the menu the moment the
plugin finishes loading — no wait, no takeoff/land cycle needed.

## User Stories

1. As a mission maker, I want a scene plugin crate to appear in the Request Equipment menu
   as soon as the plugin is loaded, so that I do not see a blank menu or need to wait 10
   seconds after mission start.

2. As a mission maker, I want the plugin crate to be visible immediately even if I am
   already spawned and parked in a logistics zone when the plugin trigger fires, so that
   test-reload workflows (Shift+R) are seamless.

3. As a plugin author, I want my plugin's crate to be visible the instant
   `CTLDSceneManager.getInstance():registerSceneModel(myScene)` returns, so that the
   load-position-independent contract is complete end-to-end (not just at the data layer).

4. As a developer, I want the instant-refresh to be a no-op when no players are active
   (e.g. at mission start before any slot is taken), so that normal batch init performance
   is unaffected.

5. As a developer, I want a regression test that verifies a transport player's
   `refreshRequestEquipmentSection` is called immediately when `_injectSceneCrate` runs
   post-init, so that a future refactor cannot silently reintroduce the delay.

## Implementation Decisions

- **Location**: `CTLDCrateManager:_injectSceneCrate`, immediately after the
  `table.insert(self._processedCrates[cat].singleCrates, pe)` line (and after the
  `ctld.utils.log("INFO", ...)` — only when a new entry was actually inserted, not on
  the idempotent early-return paths).

- **Guard**: only refresh if `CTLDPlayerManager._instance` exists (it may not exist if
  `_injectSceneCrate` is called very early — e.g. during `_processSpawnableCrates` before
  `CTLDPlayerManager` is initialised). The field is `CTLDPlayerManager._instance`, not
  `CTLDPlayerManager.getInstance()` — calling `getInstance()` here would create the
  player manager as a side effect, which is wrong.

- **Iteration**: iterate `CTLDPlayerManager._instance._players`, call
  `self:refreshRequestEquipmentSection(pObj)` for each entry where `pObj.isTransport` is
  true. `refreshRequestEquipmentSection` handles in-air / no-menu guards internally.

- **Batch init path is unaffected**: during `_processSpawnableCrates` (called inside
  `CTLDCrateManager.getInstance()`) `_injectSceneCrate` is called for each configured
  scene. At that point `CTLDPlayerManager._instance` is typically already set (player
  manager is initialised first in `ctld.initialize()`), but `_players` is empty (no
  slots taken yet). The iteration is a no-op — zero overhead.

- **No new public API**: the change is entirely inside `_injectSceneCrate`. The caller
  (`CTLDSceneManager:registerSceneModel`) requires no modification.

- **Rebuild required**: `src/CTLD_crate.lua` → rebuild `CTLD.lua`.

## Testing Decisions

Good test: assert the observable external side-effect — `refreshRequestEquipmentSection`
is called for an active transport player when `_injectSceneCrate` runs post-init. Test
via a spy on `refreshRequestEquipmentSection`, not by inspecting internal DCS menu state.

- **Seam**: busted unit test in `tests/ci/unit/`, extending or following
  `crate_lgzpoll_spec.lua` (same file is acceptable — both tests concern
  `CTLDCrateManager` post-init behaviour visible to players). Reset `_instance` in
  `before_each` as the lgzpoll spec does.

- **Spy pattern**: replace `cm.refreshRequestEquipmentSection` with a counting stub
  before calling `_injectSceneCrate`; assert it was called at least once for the
  transport player.

- **Cases**:
  1. Transport player present (`isTransport=true`) → refresh called.
  2. Non-transport player present (`isTransport=false`) → refresh NOT called.
  3. No players present (`_players = {}`) → no error, no call.
  4. Idempotent inject (same scene registered twice) → refresh NOT called on second call
     (early-return path).

- **Prior art**: `crate_lgzpoll_spec.lua` for the instance-reset + player-stub pattern.

## Out of Scope

- Refreshing other menu sections (Load Crate, Unpack, etc.) on plugin inject — only
  Request Equipment is affected by a new crate appearing in `_processedCrates`.
- Changing the 10-second LGZ poll cadence — the poll remains useful for zone entry/exit
  and is not replaced by this change.
- Any change to `CTLDSceneManager:registerSceneModel` or the plugin API contract.

## Further Notes

PR #37 (FIX-LGZ-POLL-NIL-ISFLYING) is a prerequisite for correct ongoing behaviour
(players who never take off must still get zone-change refreshes via the poll). This lot
is additive: it closes the UX gap between "crate registered" and "menu updated" from
≤10 s to ≤0 s.
