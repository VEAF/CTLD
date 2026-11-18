# 01 — The scripted troop drops drop the troops again

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-TROOP-UNLOAD-TRANSPORT](../PRD.md). Stories 1-10.

## What to build

`unloadTransport` and `unloadInProximityToEnemy` of the troop manager, and so the deprecated `ctld.unloadTransport` and `ctld.unloadInProximityToEnemy`, work again. They asked the troop manager for a drop method that no longer exists and raised an error.

- **`unloadTransport`**: in an extraction zone the troops are dropped to the objective; otherwise in a pickup zone they go back to its stock; otherwise every group on board is dropped. No troops on board, or an unknown unit: nothing happens and it answers false.
- **`unloadInProximityToEnemy`**: an AI transport with an enemy in sight drops every group; with none in sight it drops nothing; a player-controlled transport is left alone.

The drop and the return publish the troop events added by FEAT-TROOP-GESTURE-EVENTS.

## Acceptance criteria

- [ ] `unloadTransport` drops every group on board, without raising an error.
- [ ] Standing in a pickup zone, it returns the troops to the stock and drops nothing; an extraction zone takes priority and drops the troops to the objective.
- [ ] With no troops on board, or for an unknown unit, it answers false without raising an error.
- [ ] `unloadInProximityToEnemy`: an AI transport with an enemy in sight drops every group; with no enemy in sight it drops nothing; a player-controlled transport is left alone.
- [ ] The deprecated `ctld.unloadTransport` and `ctld.unloadInProximityToEnemy` wrappers work.
- [ ] The new cases fail before the change and pass after it; the existing troop specs pass unchanged.
- [ ] CHANGELOG `[Unreleased]` entry; `busted tests/ci/` green; luacheck clean; no new translation key.
- [ ] The lot's line in `.backlog/README.md` ("in progress") is set to `merged (PR #NN)` in this PR.

## Blocked by

None - can start immediately.
