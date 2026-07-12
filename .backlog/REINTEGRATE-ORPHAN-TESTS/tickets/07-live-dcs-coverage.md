# 07 — Live-DCS coverage (real engine required)

Status: ✅ done
Type: hybrid (AFK authoring + live DCS validation)

## What to build

Tagged `@tier` scenarios under `tests/dcs/noPlayer/` (contract-of-return, injected via
VEAF-dcs-bridge) for the behaviours that genuinely need the real DCS engine — not busted-able.

Re-integrates relics:
- F-006 `dropBeacon` — spawns 3 real units + freq + `OnBeaconDropped` (real spawn)
- F-007 `removeClosestBeacon` — removal + `OnBeaconRemoved` (reason=manual)
- F-092 `dropBeacon` with `overridePosition`=centroid, isFOB → infinite battery
- F-009 recon `scan()` — `OnReconScan` payload (activeLayers/targets), needs real enemies in mission
- F-018 `loadVehicle` method=`dcs_native` → LOADED + `OnVehicleLoaded` (real DCS unit)
- F-019 `unloadVehicle` method=`dcs_native` on ground → WAITING + `OnVehicleUnloaded`

## Approach

New scenarios from `tests/dcs/_template_noPlayer.lua` (or `_template_scenario.lua`), tier `auto`
or `auto-check`. Follow the return contract (`_SCN_<ID>_RESULT`, verdict grammar). Validate live
via `python tools/integration-runner/run_scenarios.py --scenario <name> --no-ai` against a running
DCS mission (requires David's DCS + dcs-serve up).

NB: this is the ONLY ticket needing a live DCS session; it runs after the busted tickets.
Corrections to relic assumptions flagged by the audit (F-018 `unit` kept alive in dcs_native;
F-092 beacon position) must be applied when authoring.

## Acceptance criteria

- [ ] Each scenario carries a valid `-- @tier:` header and the return contract.
- [ ] `luac5.1 -p` clean on each.
- [ ] Each scenario PASSes live via the headless runner (needs DCS up — validate with David).

## Blocked by

Tickets 01–06 (busted lots first). Live validation gated on a DCS session.
