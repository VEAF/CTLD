# 03 — Scene structures + minefields

Status: ✅ done
Type: AFK

## What to build

Busted coverage for scene model structure and minefield mine-count logic (pure/deterministic).

Re-integrates relics:
- F-043 "FARP Alpha" scene — structure (steps, registry keys, polar layout) via the registered
  scene model (`src/scenes/CTLD_farpAlphaScene.lua`)
- F-091 `farpScene` — structure (6 steps, SINGLE_HELIPAD/FARP_Tent…), Part 1 only (visual spawn
  is the `ia` part, out of scope here)
- F-083 `setLandMine` 1×1 → 1 mine
- F-084 `setLandMine` 5×15 staggered → 68 mines (8×5 + 7×4)
- F-085 `setLandMine` 4×3 staggered → 11 mines (4 + 3 + 4)
- F-087 `setLandMineAuto` parametric count + single-mine branch + guards

## Approach

Structure: assert the registered scene model's step count / keys / polar params against
`src/scenes/*`. Minefields: stub the spawn primitive and count invocations for each grid.

## Acceptance criteria

- [ ] `luac5.1 -p` clean.
- [ ] Scene structure assertions track the CURRENT models (not the stale relic figures — verify
      against `src/scenes/` before writing expected values).
- [ ] Mine counts asserted for 1×1, 5×15, 4×3, and the auto/parametric path.
- [ ] `busted` job green.

## Blocked by

Ticket 01.
