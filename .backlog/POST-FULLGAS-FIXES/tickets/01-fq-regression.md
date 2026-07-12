# 01 — F-Q whole-vehicle regression (Feature Q)

Status: ✅ done
Type: AFK

Commit 0a15814 (DCS-cargo fix, FullGas fork) dropped the `loadableList` computation in
`CTLDCrateManager:refreshRequestEquipmentSection` and hardcoded `spawnAsVehicle = false`,
silently disabling whole-vehicle spawn from Request Equipment. Restored the logic from the
b1ddfe4 reference (both objects exist in our repo, read-only). src + rebuild CTLD.lua.

Validated live: scenario_fq_vehicle_whole_transport PASS 9/9 (was 1/9).

L4 pilotPassive confirmed live (2026-07-12, David, UH-1H): whole-vehicle option visible and
spawns correctly from F10 → CTLD → Request Equipment — closes the L4 gap this menu change had
skipped before merge.
