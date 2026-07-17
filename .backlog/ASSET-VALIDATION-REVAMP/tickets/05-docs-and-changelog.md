# 05 — Docs + CHANGELOG for the validation revamp

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Document the new dev-time validation workflow and the probe removal.

- **Mission-maker doc** (EN/FR): "validating your config during development" — load the companion
  `.lua` in a mission-start trigger during dev, read the WARNs, declare mod types via the `modTypes`
  setting, remove the companion for production.
- **Config reference**: the `modTypes` setting (ticket 02).
- **CHANGELOG** `[Unreleased]`: probe validation removed from `CTLD.lua` (no more spawn/destroy at
  mission start); optional companion validator added as a release asset. Note the behavioural change
  (no runtime WARN in production).

## Acceptance criteria

- [ ] Mission-maker dev-validation page EN + FR (mkdocs nav updated).
- [ ] `modTypes` documented in the config reference.
- [ ] CHANGELOG entry present; behavioural change called out.
- [ ] No FR/EN mixing within a sentence; links resolve.

## Blocked by

03, 04.
