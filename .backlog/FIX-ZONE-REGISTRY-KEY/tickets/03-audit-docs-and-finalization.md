# 03 — Audit of remaining short-name lookups, docs and finalization

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-ZONE-REGISTRY-KEY](../PRD.md). [ADR 0023](../../../dev/adr/0023-zones-designated-by-registry-key-everywhere.md).
Stories 16-19.

## What to build

Close the lot: make sure no third consumer of the zone registry still passes a short name, and leave
the docs and backlog consistent.

- Audit every other caller of the troop / logistic zone accessors (`getTroopZone`, `getLogisticZone`,
  `setTroopZoneActive`, `changeRemainingGroups`, waypoint activation, the logistic-zone equivalents),
  including the legacy compatibility layer. Check each legacy wrapper against `migration/source/CTLD.lua`
  for parity. A lookup found passing a short name is fixed by the registry-key rule, with a test.
- `docs/developer/subsystems/zones.md` and `zones.fr.md` state the registry-key rule (full name for
  auto-discovered zones, short name is a label). `docs/mission-maker/legacy-api` is updated only if the
  audit shows its examples or wording are affected.
- Remove the roadmap entry "Crate request menu — logistic zone looked up by short name (regression of
  PR #210)" from `dev/roadmap.md`.
- Set the lot's `.backlog/README.md` index line to `merged (PR #NN)` in the delivering PR, and rebuild
  `CTLD.lua` locally (it is generated and not committed) so the dictionaries are regenerated before the PR.

## Acceptance criteria

- [ ] The audit result is recorded in the PR description: every caller checked, each one either already
      correct, fixed (with a test), or noted as out of scope.
- [ ] Legacy wrapper parity against `migration/source/CTLD.lua` is stated for each wrapper touched.
- [ ] `zones.md` and `zones.fr.md` updated.
- [ ] The roadmap entry is removed from `dev/roadmap.md`.
- [ ] `.backlog/README.md` index line is `merged (PR #NN)` in the PR; all three ticket statuses are ✅.
- [ ] luacheck clean; `busted tests/ci` green.

## Blocked by

- [01 — Zone registry key and the two F10 menu fixes](01-registry-key-and-menu-fix.md)
- [02 — Event payloads identify zones by registry key](02-homogeneous-event-payloads.md)
