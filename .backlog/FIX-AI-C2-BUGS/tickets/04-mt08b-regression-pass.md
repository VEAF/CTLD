Status: ⬜ ready
Type: AFK

# 04 — MT-08B regression: verify PASS after all C2 fixes

## What to build

`scenario_mt08b_weight_exceeded` (tier `auto-slow`) was created to expose both C2 bugs
end-to-end. Currently FAIL: Leopard-2 spawns at the dropoff zone. Once tickets 01, 02 and 03
are merged, run the scenario to confirm both bugs are fixed and cannot regress.

Run command:
```
python tools/integration-runner/run_scenarios.py --tier auto-slow --poll-timeout 900
```

Expected outcome: MT-08B reaches PASS — no unexpected spawn at dropoff, physical HMMWV
survives in the pickup zone. If still failing, diagnose and reopen the relevant upstream
ticket before closing this one.

## Acceptance criteria

- [ ] `scenario_mt08b_weight_exceeded` verdict is `PASS` under `--tier auto-slow --poll-timeout 900`
- [ ] No unexpected vehicle (Leopard-2 or other) spawned at the dropoff zone
- [ ] Physical HMMWV is still alive in the pickup zone after the helo departs
- [ ] No regression on other `auto-slow` scenarios

## Blocked by

- Ticket 01 (fix C2 guard)
- Ticket 02 (fix invalid typeName in config)
- Ticket 03 (validate typeNames at load time)
