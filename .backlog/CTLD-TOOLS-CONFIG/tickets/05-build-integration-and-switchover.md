# 05 — Build integration + switch-over

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Wire the generator into the build and flip the source of truth. Only proceed once ticket 04 is green.

- **`merge_CTLD.ps1`**: run `gen-config` (via the Python package) before assembling `CTLD.lua`; the
  generated Lua is a build artefact (git-ignored), inserted via `listToMerge.txt` at the right
  boundary. Hard-fail with an explicit message if Python / the generator is unavailable (mirror the
  existing BOM/empty-output fail style).
- **`ci.yml` + `release.yml`**: add `setup-python` on the Windows merge job; both build the
  deliverable the same way.
- **`CTLDConfig:load()`**: remove the inline `self.settings[...]` defaults block; instead copy the
  generated defaults table into `self.settings`. The user-YAML merge (`ctld.yamlConfigDatas` →
  `parseYAML`) and backward-compat block stay **unchanged**.

After this, `ctld-config.yaml` is the sole source of truth; the defaults no longer live in Lua source.

## Acceptance criteria

- [ ] `merge_CTLD.ps1` generates then merges; git-ignored generated Lua; explicit fail if Python absent.
- [ ] `ci.yml` + `release.yml` Windows merge job runs `gen-config` via `setup-python`.
- [ ] Inline defaults removed from `CTLD_config.lua`; `load()` copies the generated table; merge/compat unchanged.
- [ ] `CTLD.lua` rebuilds; `luac5.1 -p` clean; busted suite green (no behavioural change).
- [ ] Parity test (ticket 04) still green against the built deliverable.

## Blocked by

Ticket 04.
