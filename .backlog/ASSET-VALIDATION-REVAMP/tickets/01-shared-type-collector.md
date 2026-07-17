# 01 — Extract a shared configured-type collector

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The logic "collect every DCS type referenced by the live config + registry" currently exists twice:
in `CTLD_modValidator` (runtime, feeds the probe) and in `tests/ci/unit/config_types_lint_spec.lua`
(`collectConfiguredTypes`). The companion (ticket 03) needs it a third time. Extract it once.

Provide a single helper that, given the loaded CTLD state, returns the set of configured types with
their source (`spawnableCrates`, `loadableGroups`, AA templates, `CTLDObjectRegistry._db`). It must
also surface the **declared extras**: the union of `model.modTypes` across registered scene models
plus the MM config whitelist (ticket 02).

## Acceptance criteria

- [ ] One shared collector; `config_types_lint_spec.lua` and the companion both consume it.
- [ ] Returns configured types + source; exposes the declared-extras union.
- [ ] No behavioural change to the existing busted linter beyond sourcing from the shared helper.
- [ ] busted-tested; Lua 5.1; luacheck clean.

## Blocked by

None (but coordinate with SCENE-PLUGINS ticket 02, which introduces `model.modTypes`).
