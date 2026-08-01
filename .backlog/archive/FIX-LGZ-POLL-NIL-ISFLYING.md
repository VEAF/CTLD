# FIX-LGZ-POLL-NIL-ISFLYING

**Status:** ✅ merged (PR #37). Compacted from `FIX-LGZ-POLL-NIL-ISFLYING/` on 2026-08-01; the ticket files live on in git history.

LGZ ground-position poll skips players with `_isFlying=nil` (never flown) — `== false` guard → `~= true`; regression test. Diagnosed via dcs-bridge 2026-07-19.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-fix-lgz-poll-guard` | ⬜ ready | 01 — Fix LGZ poll guard: `== false` → `~= true` |
| `02-regression-test` | ⬜ ready | 02 — Regression test: LGZ poller processes player with _isFlying=nil |

## PRD

Status: ✅ merged (PR #37)

## FIX-LGZ-POLL-NIL-ISFLYING — LGZ ground-position poll skips players with unset _isFlying

### Problem Statement

When a player spawns on the ground and never takes off, the "Request Equipment" menu does
not update to reflect crates injected after the initial menu build (e.g. a scene plugin
loaded via a second mission trigger after CTLD). The menu stays frozen at the content it
had when the player first entered the slot.

The symptom is specifically that scene plugin crates (e.g. Metal FARP from
`VEAF/CTLD_plugins`) do not appear in `CTLD → Request Equipment → <zone> → Both` even
though the plugin loaded correctly and the crate is present in `CTLDCrateManager._processedCrates`.

Confirmed via dcs-bridge live diagnosis (2026-07-19): `CTLDSceneManager._models["Metal FARP"]`
was populated, `_processedCrates["Both"]` contained the entry — but `_lgzKey` was nil and
the menu had never been refreshed after the plugin loaded.

### Solution

Fix the condition in the LGZ ground-position poller that gates the per-player
`refreshRequestEquipmentSection` call. The poller must treat `_isFlying = nil`
(never flown — initial state) as equivalent to `_isFlying = false` (on ground).

### User Stories

1. As a mission maker, I want the Metal FARP crate (and any other scene plugin crate) to
   appear in my Request Equipment menu immediately at mission start — without having to
   take off and land — so that I can deploy the plugin scene from a cold-start position.

2. As a mission maker, I want scene plugins loaded via a secondary mission-start trigger to
   behave identically to built-in scenes in the Request Equipment menu, so that I can ship
   a mission with external plugins without special workarounds.

3. As a developer, I want the LGZ ground-position poller to handle all "player is on the
   ground" states consistently (never flown, just landed), so that future menu refresh logic
   does not diverge between initial and post-flight states.

4. As a developer, I want a regression test that explicitly exercises the nil `_isFlying`
   case in the poller guard, so that this bug cannot silently re-appear in a refactor.

### Implementation Decisions

- **Root cause**: `CTLDCrateManager._lgzGroundPoll` (in `src/CTLD_crate.lua`) gates the
  per-player refresh with `if pObj._isFlying == false`. In Lua 5.1, `nil ~= false`, so
  a player whose `_isFlying` was never assigned (initial state when spawned on the ground)
  is silently skipped by every tick of the 10-second poll.

- **`_isFlying` lifecycle**: the field is set to `true` by `onTakeoff` (and by the
  flight-state debounce poller on confirmed takeoff), and to `false` by `onLand` (and by
  the same poller on confirmed landing). `CTLDPlayer:new({...})` does not initialize it,
  so it stays `nil` for the entire session if the player never leaves the ground.

- **Fix**: change the guard condition from:
  ```lua
  if pObj._isFlying == false then
  ```
  to:
  ```lua
  if pObj._isFlying ~= true then
  ```
  This treats `nil` (never flown) identically to `false` (has landed): both mean the
  player is on the ground and eligible for the zone-change poll.

- **No initialization change needed**: deliberately do not initialize `_isFlying = false`
  in `CTLDPlayer:new`. Other code paths that read `_isFlying` check `~= nil` first (e.g.
  the `overrideInAir` fall-through in `refreshRequestEquipmentSection` line ~2800 and
  `buildMenuSection` line ~899), so the nil state is expected and handled there. Changing
  the poll guard is the minimal surgical fix.

- **Rebuild required**: `src/CTLD_crate.lua` change → rebuild `CTLD.lua`.

### Testing Decisions

Good test for this fix: assert the observable external behavior — `refreshRequestEquipmentSection`
is called (or not called) for a player based on the value of `_isFlying` and the zone key.
Test the guard condition directly, not the DCS timer internals.

- **Preferred seam**: busted unit test in `tests/unit/` mocking `CTLDPlayerManager._players`
  with a stub `playerObj` where `_isFlying = nil`. Invoke the poller body logic and confirm
  that `refreshRequestEquipmentSection` is called.
- **Prior art**: `tests/unit/CTLD_crate_spec.lua` (L1) or `tests/unit/CTLD_player_spec.lua`
  (L1) for the pattern; look at how other guard conditions in the crate manager are tested.
- **Alternative**: an integration test (`tests/dcs/noPlayer/`) that directly invokes the
  poller body with a stub player having `_isFlying = nil`, and checks `_lgzKey` is updated.
  This is lower priority — the unit test covers the guard logic sufficiently; the live
  scenario F-124 already covers the broader plugin post-init contract.
- **Do NOT** test the 10-second `timer.scheduleFunction` cadence — that is DCS internals,
  not observable CTLD behavior.

### Out of Scope

- Changing how `CTLDPlayer:new` initializes `_isFlying` (unnecessary for the fix; risks
  subtle behavior change in paths that check `~= nil` before reading the field).
- Adding a new L3 DCS integration scenario exclusively for this fix (F-124 already covers
  the plugin post-init contract; a unit test is sufficient for the guard condition).
- Any Metal FARP plugin changes — the plugin code is correct; the bug is entirely in CTLD.

### Further Notes

Workaround (no code change): take off and immediately land. `onLand` sets `_isFlying = false`
and calls `refreshRequestEquipmentSection` directly, which picks up the injected crate.
This workaround was confirmed in-session (2026-07-19) before the fix lot was opened.
