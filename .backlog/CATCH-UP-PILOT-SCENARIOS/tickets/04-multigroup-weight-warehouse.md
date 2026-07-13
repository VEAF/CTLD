# 04 — Multi-group / weight / warehouse

Status: 🚧 in progress
Type: mixed — 4 of 5 retagged `auto-check` (audited before running, per the ticket 03 lesson);
only `scenario_warehouse_cycle.lua` is genuine `ia (fly)`

## Scenarios

Audited each one's actual code before asking for a pilot (per the ticket 03 mistagging lesson)
— 4 of 5 need no piloting at all:

- `tests/dcs/pilotPassive/scenario_multigroup_transport.lua` → `auto-check`. Fully
  self-contained: mocks `ctld.MenuManager`/`Unit.getByName` with a fake unit, doesn't touch a
  real player at all.
- `tests/dcs/pilotPassive/scenario_weight_aggregation.lua` → `auto-check`. "1 step auto" per
  its own header; just needs a BLUE slot for position.
- `tests/dcs/pilotPassive/scenario_unpack_jtac_drone.lua` → `auto-check`. Resolves the
  helicopter via hardcoded `Unit.getByName("uh1-1")`, not `coalition.getPlayers` — no active
  piloting needed. Single injection, ~13 min of internal timers (up to T+795s) — needs a long
  poll timeout if run via `run_scenarios.py`.
- `tests/dcs/pilotPassive/scenario_farp_repack.lua` → `auto-check`. **Found + fixed a second
  premature-reinjection bug** (same family as TFC's step-7 race, ticket 03): step 2 checked for
  an active FARP scene and called `fail()` outright if not found yet, but `playSceneAtPos`
  (step 1) takes ~15-20s to actually register the scene — a tight automated re-inject loop
  (every 2s) hits step 2 well before that and gets a false FAIL. Fixed: step 2 now retries
  (bounded, 20 attempts) instead of failing immediately, only failing for real past that.
- `tests/dcs/pilotActive/scenario_warehouse_cycle.lua` → stays `ia (fly)`. Genuine piloting:
  crate load, takeoff, FARP deploy, reposition >400m, land — real `inAir()`/`setHumanStep` use.

Run the 4 `auto-check` ones via `run_ia_scenario.py` (still works) or `run_scenarios.py
--no-ai` (`--poll-timeout 900` or higher for `scenario_unpack_jtac_drone.lua`). Only
`scenario_warehouse_cycle.lua` needs you to actually fly.

## Acceptance criteria

- [ ] All 5 injected, verdicts read.
- [ ] Any FAIL root-caused and fixed.
- [x] Tier audited before running (4 of 5 retagged `auto-check`).
