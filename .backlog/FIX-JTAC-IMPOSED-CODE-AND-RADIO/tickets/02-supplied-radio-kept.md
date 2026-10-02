# 02 — A supplied radio is kept

**Status:** ⬜ ready — decision b of the PRD first

Files: `src/CTLD_jtac.lua` (`autoLase`, `spawnJTAC`, `CTLDJTAC:new`), busted tests.

## What to do

- `spawnJTAC` passes `cfg.radio` on to the JTAC; `CTLDJTAC:new` keeps it, and computes
  `calculateFMRadio` only when none is given.
- Apply decision b on the shape: VEAF passes its ASSETS entry (`freq = "36.0"`, `mod = "FM"`, other fields).

## Done when

- busted: a JTAC given `{ freq = "36.0", mod = "FM" }` has that radio; one given none keeps the
  code-derived radio; a code above `jtacLaserCodeMax` with a supplied radio still has one.
