Status: ⬜ ready

# 02 — Regression test: refreshRequestEquipmentSection called on _injectSceneCrate

## What

Add busted unit tests (L1) to `tests/ci/unit/crate_lgzpoll_spec.lua` (or a new adjacent
spec file) covering four cases:

1. **Transport player present** — after `_injectSceneCrate` with a new stub scene,
   `refreshRequestEquipmentSection` is called for the transport player.
2. **Non-transport player present** — player with `isTransport=false` is NOT refreshed.
3. **No players** — `_players = {}`, no error thrown, no call.
4. **Idempotent inject** — calling `_injectSceneCrate` a second time for the same scene
   (early-return path) does NOT trigger a refresh.

Use a spy (replace `cm.refreshRequestEquipmentSection` with a counter stub) to observe
call counts without invoking the real DCS menu logic.

## Acceptance

- All four cases pass.
- `busted tests\ci` green.
- Coverage ratchet does not regress.
