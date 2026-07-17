# 06 — Docs, CHANGELOG, migration guide

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Document the plugin model and the Metal FARP breaking change.

- **Mission-maker doc**: a "loading a plugin scene" page (EN + FR) — where to get the plugin `.lua`
  (the CTLD_plugins catalogue), how to load it in a MISSION START trigger *after* CTLD, the
  mission-start-only / mod-prerequisite caveats.
- **Scene-authoring contract** (developer doc): a scene's source is load-position-independent
  (mission-start only); the extension points and how each behaves when loaded after init;
  `requiresMod` metadata + whitelist; `requiresCtld`.
- **CHANGELOG** `[Unreleased]` → **Breaking**: Metal FARP removed from `CTLD.lua`, now a plugin in
  `VEAF/CTLD_plugins`; missions using it must load the plugin `.lua` in a mission-start trigger
  after CTLD.
- **Migration guide** (2.0.0): entry with the concrete load snippet + link to the catalogue.

## Acceptance criteria

- [ ] Mission-maker "loading a plugin scene" page in EN + FR (mkdocs nav updated).
- [ ] Developer scene-authoring contract page in EN + FR.
- [ ] CHANGELOG Breaking entry present.
- [ ] Migration-guide entry with the load snippet.
- [ ] No FR/EN mixing within a sentence; links resolve.

## Blocked by

05 (the breaking change these docs describe).
