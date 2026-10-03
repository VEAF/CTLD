# 01 — An imposed laser code is reserved, whatever the order

**Status:** ⬜ ready — decision a of the PRD first

Files: `src/CTLD_jtac.lua` (`spawnJTAC`, `startLaseTroopUnit`, `_assignLaserCode`, `_freeLaserCode`,
`_initLaserPool`), possibly `src/CTLD_core.lua` (INIT-C order), busted tests.

## What to do

- An imposed `cfg.laserCode` leaves `_laserPool` when it is imposed, and `_freeLaserCode` returns only
  codes that came from the pool.
- Apply decision a so that a code imposed after INIT-C does not end up shared with a JTAC INIT-C coded
  automatically.

## Done when

- busted: JTAC A imposed on 1688 then JTAC B automatic → distinct codes; JTAC B automatic first (taking
  1688) then JTAC A imposed on 1688 → distinct codes; A's death does not put 1688 back in the pool.
