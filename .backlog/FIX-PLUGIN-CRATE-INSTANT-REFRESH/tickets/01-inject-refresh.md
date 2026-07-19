Status: ⬜ ready

# 01 — Refresh active transport players immediately after _injectSceneCrate inserts

## What

In `CTLDCrateManager:_injectSceneCrate`, after the new crate entry is inserted into
`_processedCrates` (the `not already` branch), iterate
`CTLDPlayerManager._instance._players` (guard: `_instance ~= nil`) and call
`self:refreshRequestEquipmentSection(pObj)` for each player where `pObj.isTransport`
is true.

Rebuild `CTLD.lua` after the change.

## Why

Without this, a plugin crate is in the data layer immediately but the player's F10 menu
does not reflect it until the next LGZ poll tick (~10 s). The instant refresh closes the
UX gap to zero.

## Acceptance

- A transport player already connected when a plugin registers its scene gets their
  Request Equipment menu updated without any takeoff/land cycle or 10 s wait.
- `busted tests\ci` green.
- `luacheck` clean.
- `CTLD.lua` rebuilt.
