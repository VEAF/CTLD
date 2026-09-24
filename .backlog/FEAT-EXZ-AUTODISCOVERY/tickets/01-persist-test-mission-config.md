# 01 — Give `Test_CTLDNEXT_01.miz` a real per-mission `ctld.configUser`

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

`missions/Test_CTLDNEXT_01.miz` currently only loads the engine (`CTLD.lua`, via a
`CTLD_DEV_ROOT` env-var trigger — `DEV-LOCAL-MIZ`). It never gets a per-mission configuration,
unlike a real Mission Maker's exported mission. Give it one, through the same mechanism
`tools/ctld-tools/ctld_tools/install.py` already uses for a real install: a small YAML declaring
the `aiZones` entries the live regression scenarios need, wrapped into `ctld.configUser = [[...]]`
(`ctld-tools embed --var configUser`), injected as its own MISSION START trigger
(`ctld_tools.miz.inject_userconfig()`).

**Scope widened (2026-09-23, during `FEAT-CTLD-TOOLS-AIZ-SYNC`'s follow-up work):** the mission
actually carries 15 `AIZ_`-prefixed trigger zones, not 3 — the other 12 (used by MT-07, MT-10
through MT-14, and `F-176`) never got a documented config either, they just weren't the ones
diagnosed in the original incident. Persisting all 15 in one pass — instead of only the 3 below —
removes the class of bug this ticket exists to fix everywhere at once, not just where it was first
noticed. Per **a.lingo's own rule, unchanged**: this addition happens **exclusively through the
`ctld-tools` app**, never by script — the values below are what to enter in its `AiZonesEditor`,
not a YAML for me to inject.

All 15 zones, in the shape documented in `docs/mission-maker/zones.md`'s `aiZones` examples.
**Update 2026-09-24:** a.lingo renamed the 6 non-conforming zones directly in the Mission Editor
(confirmed via direct `.miz` re-read) to make every `dcsZoneName` match `ctld-tools`' own `AIZ_`
naming convention — the `G` guess below was confirmed correct for all 5 previously-unconfirmed
dropoff zones. `dcsZoneName` is the exact, current DCS zone name; the 6 live scenario files that
hardcoded the old strings have been updated to match (same session):

| `dcsZoneName` | coalition | pickup/dropoff | cargoType / aiDropMode | troopStock | vehicleStock | Used by |
|---|---|---|---|---|---|---|
| `AIZ_base_B_P_T` | BLUE | pickup | `T` | `{Standard Group: 5, Anti Tank: 2}` | — | F-176, MT-07 |
| `AIZ_front_B_D_G` | BLUE | dropoff | `G` | — | — | MT-07 |
| `AIZ_livraison_B_D_G` | BLUE | dropoff | `G` | — | — | MT-08, MT-08B, MT-09 |
| `AIZ_depot_B_P_TV_5_10` | BLUE | pickup | `TV` | `{All: -1}` | `{Hummer: 5}` | F-176, MT-09 |
| `AIZ_depot_B_P_T_10` | BLUE | pickup | `T` | `{All: -1}` | — | F-176, MT-10 |
| `AIZ_mt10d_B_D_G` | BLUE | dropoff | `G` *(name-implied, untested)* | — | — | MT-10 |
| `AIZ_depot_B_P_V_10` | BLUE | pickup | `V` | — | `{Hummer: 3, "M1045 HMMWV TOW": -1}` | F-176, MT-08, MT-08B |
| `AIZ_mt11_B_P_T` | BLUE | pickup | `T` | `{Standard Group: 3, Anti Tank: 2}` | — | MT-11 |
| `AIZ_mt11_B_D_G` | BLUE | dropoff | `G` | — | — | MT-11 |
| `AIZ_mt12_B_P_V` | BLUE | pickup | `V` | *(absent)* | `{Hummer: 2}` | MT-12 |
| `AIZ_mt12_B_D_G` | BLUE | dropoff | `G` | — | — | MT-12 |
| `AIZ_mt13_B_P_V` | BLUE | pickup | `V` | — | `{"FARP Alpha": 1}` *(scene)* | MT-13 |
| `AIZ_mt13_B_D_G` | BLUE | dropoff | `G` | — | — | MT-13 |
| `AIZ_mt14_B_P_V` | BLUE | pickup | `V` | — | `{"HAWK AA System": 1}` *(scene)* | MT-14 |
| `AIZ_mt14_B_D_G` | BLUE | dropoff | `G` | — | — | MT-14 |

The existing scenario files' own defensive `aiZones` self-registration (added in
`FIX-UH1H-CAPABILITIES-REALISM` for MT-08/MT-08B/MT-09, extended to `F-176` in this same widened
ticket) stays in place as a second safety net — this ticket fixes the root cause at the mission
level, it does not replace that safety net.

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
  trigger shape `inject_userconfig()` produces) declaring all 15 `aiZones` entries above, entered
  through the `ctld-tools` app itself (never scripted).
- After a **full DCS restart** (not merely a mission reload) with no manual configuration step,
  every live scenario that reads one of these zones — `F-176`, MT-07 through MT-14 — passes (tier
  `auto-slow`/`human` as applicable) — the signal that the persisted, mission-carried configuration
  actually took effect from a cold start.
- Re-running the same scenarios a second time in the same DCS session (no restart) still passes —
  the fix must not depend on the live-session HTTP workaround used while diagnosing this.

## Tests

Live DCS only (tier `auto-slow`), per `feedback_dcs-test-before-pr`: validated live, from a cold
DCS restart, before the PR opens. No busted seam — this ticket changes a mission asset and applies
already-tested tooling to it, it does not change `src/`.
