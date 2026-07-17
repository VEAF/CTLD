Status: ⬜ ready

# TEST-PLUGIN-POSTINIT — L3 integration test for scene plugin post-init loading

## Problem Statement

The SCENE-PLUGINS lot (PR #26) introduced a load-position-independent plugin mechanism
that allows mission makers to load scene plugins after CTLD initialises, via a mission-start
trigger. The two extension points — scene model registration and menu section deferral —
are both designed to work whether CTLD is initialised or not at the time of the call.

This contract is covered by L1/L2 busted tests (unit and functional). However, no L3/L4
DCS live test verifies it under real DCS runtime conditions. A developer or CI run cannot
currently detect a regression in the post-init plugin path without running in DCS.

## Solution

Add a single L3 (`noPlayer`) integration scenario (tier `auto`, feature number F-124) that
exercises the plugin post-init contract in a live DCS environment:

1. Confirm the stub scene is absent from the scene registry before registration.
2. Call `registerSceneModel` after CTLD init with a minimal stub plugin.
3. Confirm the scene is present in the registry and retrievable.
4. Call `deferMenuSection` after PlayerManager init.
5. Confirm the section is immediately in `_menuSections` (routed directly, not queued).
6. Confirm the pre-init queue `_deferredSections` does not contain the section.
7. Confirm that a plugin declaring `requiresCtld` above the current CTLD version logs a
   WARN but is still registered (soft-fail, not hard-fail).

## User Stories

1. As a developer, I want a DCS live test confirming that `registerSceneModel` called
   post-init adds the model to the scene registry, so that a regression in the timing
   contract is caught before release.

2. As a developer, I want a DCS live test confirming that `deferMenuSection` called
   post-init routes the section directly into `_menuSections` without going through the
   pre-init queue, so that the live routing path is verified end-to-end.

3. As a developer, I want the test to confirm that the pre-init queue is not polluted when
   a section is registered post-init, so that future calls at init time do not re-register
   already-live sections.

4. As a developer, I want the test to confirm that `requiresCtld` produces a WARN and
   still registers the model (soft-fail), so that the version-check contract is testable
   without DCS crashing.

5. As a mission maker, I want confidence that loading a plugin after CTLD (via a
   mission-start trigger) works correctly in all supported DCS configurations, so that I
   can ship plugins without fear of silent breakage.

6. As a CI maintainer, I want this test to run automatically under `--tier auto` with no
   human interaction, so that the plugin contract is part of the standard headless sweep.

## Implementation Decisions

- **Level**: L3 `noPlayer` — no real player slot required. `CTLDPlayerManager.getInstance()`
  initialises the manager programmatically; `_deferredSections` and `_menuSections` are
  directly accessible for introspection.

- **Tier**: `auto` — the scenario returns a verdict synchronously (no `waitFor` needed).
  All assertions resolve in a single injection.

- **Feature number**: F-124 (next available in the noPlayer F-series).

- **Scene stub**: a minimal valid model with a single no-op step and no crate, no mod
  dependency. Named `TestPlugin_F124` to avoid collision with production scenes.

- **Menu section stub**: `{ key="test_plugin_section_f124", manager={}, method="build",
  order=99 }`. Key is unique enough to not collide with existing sections.

- **requiresCtld test**: a second stub registered with `requiresCtld = "99.0.0"` (above
  any real CTLD version). Assert the model is present in `_models` after the call despite
  the version mismatch.

- **Cleanup**: remove both stubs from `_models` and `_menuSections` at the end of the
  scenario (restore state for subsequent scenarios in the same mission).

- **Structure**: follows `aiTransport_featureT_stockParsing_F176.lua` — pcall isolation
  scope, `check(id, desc, cond, details)` helper, `_SCN_F124_RESULT` return contract.

## Testing Decisions

Good tests for this scenario assert observable external state (registry contents, section
list membership) rather than internal call counts or private implementation details beyond
what is necessary for the contract.

- `CTLDSceneManager.getInstance():getModel("TestPlugin_F124")` — public API, returns nil
  before registration and a table after.
- `CTLDPlayerManager._instance._menuSections` — checked for key membership.
- `CTLDPlayerManager._deferredSections` — checked to confirm the section was NOT queued.

Prior art: `tests/dcs/noPlayer/aiTransport_featureT_stockParsing_F176.lua` for the
overall structure (pcall scope, check helper, result contract, double-injection guard).

## Out of Scope

- The Metal FARP scene itself — lives in `VEAF/CTLD_plugins`, not this repo.
- F10 menu visual content — not verifiable programmatically in DCS Lua.
- Loading DCS mods or mod-dependent typeNames.
- L4 `pilotPassive` scenario — the `S_EVENT_PLAYER_ENTER_UNIT` path is already covered
  by L1/L2 busted (`defer_menu_section_spec.lua`). Adding an L4 on top would duplicate
  coverage for marginal gain.

## Further Notes

The `deferMenuSection` timing-insensitivity was introduced specifically to support the
plugin use case. The route decision (direct vs queue) is the critical contract: if it
regresses to always queuing, plugins loaded post-init would have their menu section
silently lost until the next `getInstance()` call (which never happens again after init).

The `requiresCtld` soft-fail behaviour is equally important: a hard-fail would break all
missions using a plugin compiled against a newer CTLD version, even if the API used is
backward-compatible.
