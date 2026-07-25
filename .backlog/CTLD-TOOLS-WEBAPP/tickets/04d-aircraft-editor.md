# 04d — aircraft capabilities editor (capabilitiesByType)

Status: ✅ done
Type: tool (frontend) + test

Edit `capabilitiesByType` (aircraft type → capabilities) in the Data screen — explicitly required
by the DoD (datamine-backed type picking).

- Add an aircraft type via a **datamine-backed picker** (known DCS aircraft types); per-type fields:
  `cratesEnabled`, `troopsEnabled`, `canSlingload`, `canParachuteDrop`, `useNativeDcsCargoSystem`,
  `canTransportWholeVehicle`, `convertNativeLoadToCTLD`, `maxCratesOnboard`, `maxTroopsOnboard`,
  `maxWholeVehiclesOnboard`, `maxVehicleWeight`, `loadableVehiclesBLUE`, `loadableVehiclesRED`.
- Remove a type; field tooltips from `tableFields` (EN/FR).

Files: `tools/ctld-tools/web/**`, backend datamine endpoint. Depends on: 04a.
