# 03 — Build the dev-time companion validator

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The optional companion `.lua` the mission-maker loads during mission development (ADR 0007). It
reads the live CTLD state and WARNs on unknown types — **no instantiation, no events**.

- Bundle the datamine set (`dcs_types.lua`, reused as-is) + a passive validator, built to a **single
  `.lua`** via the merge tooling. Published as an **optional release asset** alongside `CTLD.lua`.
- On load (after CTLD), the validator uses the shared collector (ticket 01) to gather configured
  types, then reports each type not in `datamine ∪ declared extras (scene modTypes ∪ config
  modTypes)` via a WARN `outText` + log line.
- Loaded in a mission-start trigger during dev; omitted in production.

## Acceptance criteria

- [ ] Companion built as one loadable `.lua` (UTF-8 no BOM), header banner (version, source).
- [ ] Loaded after CTLD, it WARNs on a deliberately-bad configured type and stays silent on stock +
      whitelisted types. Verified via dcs-bridge.
- [ ] Zero spawn / zero `S_EVENT_BIRTH` (assert no probe objects created).
- [ ] Covers `spawnableCrates`, `loadableGroups`, AA templates, registry types.
- [ ] busted coverage for the validator core (pure lookup over a mocked collector).

## Blocked by

01 (shared collector), 02 (config whitelist). SCENE-PLUGINS (scene `modTypes` + datamine set).
