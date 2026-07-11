# 06 — JTAC config/deregister + recon auto-refresh

Status: ✅ done
Type: AFK

## What to build

Busted coverage for JTAC config defaults / deregistration and recon auto-refresh.

Re-integrates relics:
- F-110 `JTAC_unitTypeNames` config defaults (Hummer / SKP-11 per coalition, drone radius/altitude)
- F-112 `deregisterJTAC` — silent: no false `OnJTACDead`, laser code returned to pool, idempotent
- F-011 recon `enableAutoRefresh` / `disableAutoRefresh` + events (previous/new state)

## Approach

F-110: pure config assertions (`ctld.gs("JTAC_unitTypeNames")` etc.). F-112: sandbox — register a
JTAC, deregister, assert no `OnJTACDead` fired, `_laserPool` code freed, second deregister is a
no-op. F-011: subscribe to the auto-refresh events, toggle, assert payload state fields.

## Acceptance criteria

- [ ] `luac5.1 -p` clean.
- [ ] JTAC config defaults asserted per coalition.
- [ ] `deregisterJTAC`: no `OnJTACDead`, code pool freed, idempotent — all asserted.
- [ ] Recon auto-refresh enable/disable events asserted.
- [ ] `busted` job green.

## Blocked by

Ticket 01.
