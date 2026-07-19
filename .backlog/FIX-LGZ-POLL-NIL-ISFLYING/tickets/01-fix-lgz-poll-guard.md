Status: ⬜ ready

# 01 — Fix LGZ poll guard: `== false` → `~= true`

## What

In `src/CTLD_crate.lua`, the `_lgzGroundPoll` inner function gates the per-player
`refreshRequestEquipmentSection` call with:

```lua
if pObj._isFlying == false then
```

Change to:

```lua
if pObj._isFlying ~= true then
```

Rebuild `CTLD.lua` after the change.

## Why

`CTLDPlayer:new({...})` does not initialize `_isFlying`. It stays `nil` until the player
takes off for the first time. In Lua 5.1, `nil ~= false`, so any ground-spawned player who
has not yet flown is silently skipped by every tick of the 10-second poller.
`refreshRequestEquipmentSection` is never called for them → post-init injected crates (e.g.
scene plugin crates) do not appear in their menu.

## Acceptance

- A player spawned on the ground with `_isFlying = nil` is processed by the poller (zone
  key is updated, `refreshRequestEquipmentSection` is called when the zone changes).
- A player who is explicitly flying (`_isFlying = true`) is still skipped (no regression).
- A player who has landed (`_isFlying = false`) is still processed (no regression).
- `CTLD.lua` rebuilt clean.
- `busted tests/ci/` green.
- `luacheck` clean.
