Status: ⬜ ready
Type: AFK

# 03 — Validate vehicleStock typeNames at zone-load time

## What to build

CTLD currently passes vehicleStock keys to `coalition.addGroup()` without any validation.
When a key is not a valid DCS typeName, DCS silently substitutes Leopard-2 — no Lua error,
no CTLD log. Mission makers have no feedback.

After `parseStockTable` builds `_aiVehicleStock` in `CTLDZoneManager` (during zone config
parsing), iterate each typeName key. Call `Unit.getDescByType(typeName)`: if it returns nil,
log a CTLD ERROR and remove the entry from the stock table. `isAll` zones (no explicit type
list) bypass this check. Rebuild `CTLD.lua`.

Add an L3 (`noPlayer`) test: configure an AIZ zone with one valid and one deliberately
invalid vehicleStock entry. After zone init, assert the invalid entry is absent from
`_aiVehicleStock.current` and that a CTLD ERROR was emitted. Prior art:
`tests/dcs/noPlayer/aiTransport_featureT_stockParsing_F176.lua`.

## Acceptance criteria

- [ ] At mission start, each vehicleStock key is validated via `Unit.getDescByType()`
- [ ] An invalid key produces a CTLD ERROR log entry and is absent from `_aiVehicleStock.current`
- [ ] A valid key is retained unchanged
- [ ] `isAll` zones are not affected
- [ ] L3 test passes in DCS (noPlayer): invalid entry removed, valid entry retained, ERROR logged
- [ ] `CTLD.lua` rebuilt from `src/`
- [ ] `luacheck` clean on modified files

## Blocked by

None — can start immediately.
