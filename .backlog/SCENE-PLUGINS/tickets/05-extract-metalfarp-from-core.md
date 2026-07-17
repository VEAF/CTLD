# 05 — Extract Metal FARP from CTLD core

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Remove `scenes/CTLD_metalFarpScene.lua` from `tools/build/listToMerge.txt` and delete the file from
`src/` — its source moves to `CTLD_plugins` (ticket 08). After this, `CTLD.lua` no longer bundles
Metal FARP, so no mission gets its mod-check WARN unless it opts into the plugin.

This is the breaking change. It must land together with the docs/migration ticket (06) so users are
told how to re-add Metal FARP as a plugin.

## Acceptance criteria

- [ ] `CTLD_metalFarpScene.lua` removed from `listToMerge.txt` and deleted from `src/scenes/`.
- [ ] Rebuild `CTLD.lua`; the Metal FARP model, crate and i18n keys are gone from the deliverable.
- [ ] No dangling references to Metal FARP in `src/` (grep clean).
- [ ] Any built-in test referencing Metal FARP is removed or relocated to `CTLD_plugins`.
- [ ] busted + luacheck clean.

## Blocked by

03 (audit removal), 08 (Metal FARP must exist as a plugin before it is deleted from core — or at
least the move must be coordinated so the scene is never lost).
