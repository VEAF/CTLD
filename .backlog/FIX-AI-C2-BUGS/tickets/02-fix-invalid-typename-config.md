Status: ⬜ ready
Type: AFK

# 02 — Replace invalid typeName in virtual stock example config

## What to build

The example vehicleStock config in `CTLD_userConfig.lua` contains
`["M1025 HMMWV Armament"] = -1`. This is not a valid DCS typeName: live injection confirmed
that `unit:getTypeName()` returns `"Hummer"` for all HMMWV variants, and DCS logs
`ERROR woCar: Unit M1025 HMMWV Armament is unknown, replaced with Leopard-2` when C2 tries
to spawn it.

Replace this entry with `["M1045 HMMWV TOW"] = -1` — the typeName confirmed from the
mission file for the "ATGM-1" unit (anti-tank HMMWV). Apply the same replacement in all
documentation files that reproduce this example. Rebuild `CTLD.lua` after the config change.

## Acceptance criteria

- [ ] `["M1025 HMMWV Armament"]` no longer appears in `CTLD_userConfig.lua`
- [ ] `["M1025 HMMWV Armament"]` no longer appears in `README.md`
- [ ] `["M1025 HMMWV Armament"]` no longer appears in `docs/mission-maker/zones.md`
- [ ] `["M1025 HMMWV Armament"]` no longer appears in `docs/mission-maker/zones.fr.md`
- [ ] All four files now show `["M1045 HMMWV TOW"] = -1` in the same position
- [ ] `CTLD.lua` rebuilt from `src/`

## Blocked by

None — can start immediately.
