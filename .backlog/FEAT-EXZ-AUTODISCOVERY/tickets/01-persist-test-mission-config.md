# 01 — Give `Test_CTLDNEXT_01.miz` a real per-mission `ctld.configUser`

**Status:** ⬜ ready

**Blocked by:** none — can start immediately.

## What to build

`missions/Test_CTLDNEXT_01.miz` currently only loads the engine (`CTLD.lua`, via a
`CTLD_DEV_ROOT` env-var trigger — `DEV-LOCAL-MIZ`). It never gets a per-mission configuration,
unlike a real Mission Maker's exported mission. Give it one, through the same mechanism
`tools/ctld-tools/ctld_tools/install.py` already uses for a real install: a small YAML declaring
the three `aiZones` entries the live regression scenarios need, wrapped into
`ctld.configUser = [[...]]` (`ctld-tools embed --var configUser`), injected as its own MISSION
START trigger (`ctld_tools.miz.inject_userconfig()`).

The three zones, in the shape documented in `docs/mission-maker/zones.md`'s `aiZones` examples:

- `AIZ_depot_B_P_V_10` — BLUE, pickup, vehicle cargo (used by MT-08, MT-08B)
- `AIZ_depot_B_P_TV_5_10` — BLUE, pickup, troops + vehicle cargo (used by MT-09)
- `AIZ_livraison_B_D_G` — BLUE, drop-off, ground only (used by MT-08, MT-08B, MT-09)

The three `tests/dcs/pilotPassive/scenario_mt08*.lua` / `scenario_mt09*.lua` files' own defensive
`aiZones` self-registration (added in `FIX-UH1H-CAPABILITIES-REALISM`) stays as-is — this ticket
fixes the root cause at the mission level, it does not replace that safety net.

## Watch out

- `inject_userconfig()`'s trigger must precede the engine's own loading trigger — already
  guaranteed by DCS's own evaluation order (MISSION START fires before a ONCE trigger whose
  condition is already true at t=0), confirmed by reading `install.py`'s own docstring ("the
  engine reads `ctld.configUser` as it loads"). Don't second-guess this by adding an artificial
  delay or reordering — it's correct as the tool already builds it.
- Don't touch the existing `CTLD_DEV_ROOT` engine-loading trigger (`DEV-LOCAL-MIZ`) — only add the
  new configuration trigger alongside it.
- `tools/ctld-tools/tests/test_miz.py` already covers `inject_userconfig()`'s mechanism
  generically (rank-1 placement, idempotent reinjection, round-trip) — no new Python test needed
  for the mechanism itself.
- The vehicle/troop stock values in the `aiZones` entries should be generous enough that MT-08's
  own weight-override trick and MT-08B's Hummer-exclusion trick (both already in place) keep
  working unmodified — don't tighten a stock number "for realism" as a side effect of this ticket.

## Acceptance

- `missions/Test_CTLDNEXT_01.miz` carries a `CTLD_userConfig.lua`-shaped resource (or the inline
  trigger shape `inject_userconfig()` produces) declaring the three `aiZones` entries above.
- After a **full DCS restart** (not merely a mission reload) with no manual configuration step,
  `scenario_mt08_ai_vehicle.lua`, `scenario_mt08b_weight_exceeded.lua` and
  `scenario_mt09_ai_full_cycle.lua` all pass live (tier `auto-slow`) — the signal that the
  persisted, mission-carried configuration actually took effect from a cold start.
- Re-running the same three scenarios a second time in the same DCS session (no restart) still
  passes — the fix must not depend on the live-session HTTP workaround used while diagnosing this.

## Tests

Live DCS only (tier `auto-slow`), per `feedback_dcs-test-before-pr`: validated live, from a cold
DCS restart, before the PR opens. No busted seam — this ticket changes a mission asset and applies
already-tested tooling to it, it does not change `src/`.
