# 05 — Config, VMCT contract doc, CHANGELOG and release notes

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FEAT-FAT-COW](../PRD.md).

## What to build

- One `fatCow` block in `src/CTLD_config.yaml` + schema (EN/FR labels) + `configVersion` bump + catalogue shape + regenerated oracles.
- `docs/pilot/` and `docs/mission-maker/` pages, EN + FR: flying a cow, requesting one, and the contract VMCT relies on (config keys, how a mission-placed AI CH-47 is declared a cow).
- `CHANGELOG.md` `[Unreleased]`, and a release-notes line poking fun at ED's native Fat Cow, announced on 2024-04-19 and 2024-08-23 and absent from DCS 2.9.30.28738.

## Acceptance criteria

- [x] `test_catalogue_shape.py` and `config_spec.lua` green; docs build; CHANGELOG guard green.
