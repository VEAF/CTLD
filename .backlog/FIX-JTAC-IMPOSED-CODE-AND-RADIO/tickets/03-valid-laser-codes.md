# 03 — The laser pool holds valid codes only

**Status:** ✅ done — rule from the legacy `ctld.generateLaserCode`, to verify in game (is 1199 refused?)

Files: `src/CTLD_jtac.lua` (`_initLaserPool`), busted tests, the mission-maker docs on laser codes.

## What to do

- Verify in DCS (or a sourced reference) which codes a laser accepts: the reporter says none with a 9 or
  a 0 (1199). Record the measurement, then leave the refused codes out of `_initLaserPool`.

## Done when

- The rule is written down with its source; busted: the pool holds no refused code; the docs say which
  codes CTLD hands out.
