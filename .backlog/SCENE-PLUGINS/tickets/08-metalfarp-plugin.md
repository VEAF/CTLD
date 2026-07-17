# 08 — Metal FARP plugin

Status: 🧑 planned
Type: AFK
Repo: CTLD_plugins

## What to build

Port `CTLD_metalFarpScene.lua` into `CTLD_plugins` as the first real plugin — ideally a **brute-force
copy** of the CTLD source (proving the load-position-independent contract), plus plugin metadata.

- `plugins/metal-farp/src/` — the scene source (copied from CTLD before it is deleted in SCENE-PLUGINS
  ticket 05).
- `modTypes = { "Farp_FG_Petit_Helipad" }` on the scene model (the extra-types whitelist; passes the
  hard-gate and is read at runtime by the Lot B companion) + `requiresMod = "<human mod name>"` for
  the catalogue/WARN.
- `requiresCtld` set to the CTLD version that ships the plugin machinery.
- `plugins/metal-farp/tests/` — the hard-gate busted test + a dcs-bridge `auto` scenario validating
  the scene builds in a live mission (run by us, with CTLD + the mod).
- `plugins/metal-farp/docs/` — catalogue entry (EN/FR): what it is, required mod, load snippet.

## Acceptance criteria

- [ ] Metal FARP scene registers and builds when its plugin `.lua` is loaded after CTLD (verified via
      dcs-bridge, mission-start trigger).
- [ ] Hard-gate test passes with the mod whitelist; would fail without it (whitelist is load-bearing).
- [ ] `requiresMod` WARN fires **only** when this plugin is loaded (never in a mission that omits it).
- [ ] Built `.lua` carries the header banner (version, requiresCtld, required mod).
- [ ] Catalogue entry EN + FR.

## Blocked by

07 (repo scaffold). Coordinated with SCENE-PLUGINS ticket 05 (source moves out of CTLD).
