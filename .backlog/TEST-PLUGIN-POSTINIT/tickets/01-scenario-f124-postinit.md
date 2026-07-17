Status: ⬜ ready

# 01 — Implement F-124 post-init plugin scenario

## What to build

Write a single L3 `noPlayer` scenario (tier `auto`, feature F-124) that verifies the post-init
plugin contract end-to-end in a live DCS environment, following the pcall/check/result structure
of the F-176 prior art.

The scenario, injected after CTLD is fully initialised:

1. Asserts `getModel("TestPlugin_F124")` returns nil (scene not yet registered).
2. Calls `CTLDSceneManager.getInstance():registerSceneModel(stub)` with a minimal stub scene
   (single no-op step, no crate, no mod dependency, name `TestPlugin_F124`).
3. Asserts `getModel("TestPlugin_F124")` returns a non-nil table.
4. Calls `CTLDPlayerManager.deferMenuSection(sectionDef)` with a stub section
   (`key = "test_plugin_section_f124"`, unique to avoid collision).
5. Asserts the key is present in `CTLDPlayerManager._instance._menuSections`.
6. Asserts the key is absent from `CTLDPlayerManager._deferredSections` (direct routing, not queued).
7. Registers a second stub with `requiresCtld = "99.0.0"` (above any real CTLD version).
8. Asserts the second stub IS present in `_models` despite the version mismatch (soft-fail).
9. Cleans up both stubs from `_models` and `_menuSections` to avoid state contamination for
   subsequent scenarios in the same mission.
10. Updates `CHANGELOG.md` `[Unreleased]` section.

## Acceptance criteria

- [ ] `tests/dcs/noPlayer/pluginPostInit_F124.lua` exists with `-- @tier: auto` header
- [ ] Double-injection guard and CTLD-ready guard present (matching F-176 pattern)
- [ ] All 7 assertions (F-124.1 – F-124.7) pass when injected into a live DCS mission
- [ ] Stubs are removed from `_models` and `_menuSections` at the end of the scenario
- [ ] CHANGELOG `[Unreleased]` updated

## Blocked by

None — can start immediately.
