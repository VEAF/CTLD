Status: ready

# 05 — L3 DCS noPlayer scenario: Moving Zone live position tracking

## What

Write an `auto-check` tier L3 scenario that exercises the full Moving Zone feature against the
live DCS mission (`missions/Test_CTLDNEXT_01.miz`), using the test assets added in the .miz:
- `CTLD_TEST_ANCHOR_1` — vehicle with a route
- `LGZ_polygonAnchored_B` — polygon Moving Zone (linkUnit=50)
- `TRZ_CircularAnchored_B_999_nil_0` — circular Moving Zone (linkUnit=50)

## Test steps

1. Read `getCenter()` for both zones at t=0 — record positions.
2. Wait for anchor vehicle to move (timer / `waitFor`, ~10–15 s).
3. Re-read `getCenter()` — assert positions differ from t=0 (zone followed unit).
4. Assert `isDynamic()` returns true for both zones.
5. Destroy anchor unit via `unit:destroy()`.
6. Wait one scheduler tick.
7. Assert `isAlive()` returns false for both zones.

## Placement

`tests/dcs/noPlayer/` — tier `auto-check` (timer-based, no player needed).

## Definition of done

- Scenario runs headlessly via `run_scenarios.py --headless`.
- PASS when positions change and isAlive() goes false after destroy.
- ABORT if CTLD not initialized or zones not found.
