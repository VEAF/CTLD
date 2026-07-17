# 07 — Bootstrap the CTLD_plugins repo

Status: 🧑 planned
Type: AFK
Repo: CTLD_plugins (new — https://github.com/VEAF/CTLD_plugins.git)

## What to build

Scaffold the new `VEAF/CTLD_plugins` repository (ADR 0006).

- Layout: `plugins/<scene>/{src,tests,docs}`.
- Shared: `tests/data/dcs_types.lua` **vendored** from CTLD, pinned to the **same ref**; document
  the sync step (re-copy when CTLD bumps the datamine ref). The hard-gate busted spec (SCENE-PLUGINS
  ticket 02) copied ~as-is.
- Per-plugin build: a `listToMerge`-per-scene producing **one** UTF-8-no-BOM `.lua` per scene, with
  a header banner (plugin version, `requiresCtld`, required mods). Mirror CTLD's `merge_CTLD.ps1`.
- Bilingual (EN/FR) **mkdocs catalogue** mirroring CTLD's mkdocs-material setup — one catalogue
  entry per plugin (description, required mods, `requiresCtld`, load snippet).
- CI/CD: busted hard-gate + dcs-bridge integration tests (`auto` tier) + build all plugin
  artifacts + publish catalogue + attach built `.lua` as release assets.

## Acceptance criteria

- [ ] Repo initialised with the layout above; Git Flow `develop`/`master`.
- [ ] Vendored datamine set present, ref documented as matching CTLD.
- [ ] Per-plugin build produces a single loadable `.lua` (UTF-8 no BOM) with the header banner.
- [ ] mkdocs catalogue builds EN + FR.
- [ ] CI green on an empty/template plugin set (real plugins land in 08/09).

## Blocked by

02 (the hard-gate spec to copy). Coordinated with 08/09 (first plugins).
