# 01 — land in a clearing, forget a vanished cow

Status: done

See the [PRD](../PRD.md).

## Acceptance

- The Land task point is the nearest `Disposition.getSimpleZones` candidate within 300 m of the point 120 m left of the leader, at the widest clearance (100, 50, 30 m) that offers one, on land and at least 60 m from the leader; the asked point when there is none or the call fails.
- An AI cow whose unit no longer exists is forgotten within 10 s, as if it had died: its flight can request another cow.

## Live check (Zip, then Claude drives)

Kit: `Test_FatCow_Takeover.miz` in Zip's `Saved Games\DCS\Missions` (not in the repository: it embeds a built `CTLD.lua` and `dcs-bridge.lua`), rebuilt with this branch's `CTLD_fatCow.lua` spliced into the `dev` build (`ctld.VERSION` `2.0.0-rc15-f49c6c7+ai-landing-2`).

1. Claude starts `dcs-serve` (`tools/dcs-bridge/venv/Scripts/dcs-serve.exe --config dcs-serve.yaml`, from the main checkout).
2. Zip opens the mission, slot **Gunfighter**, stays on the ground, no pause.
3. Claude injects a probe (cow state every second, every event naming the cow) and re-injects `tests/dcs/pilotPassive/scenario_fatcow_takeover.lua` every 20 s until PASS / FAIL / ABORT.

Expected: the cow lands at Hawk's first stop and lives; the scenario then runs the FEAT-FAT-COW-TAKEOVER take-over, release and RTB, and passes.

Result (2026-10-30): **PASS**. The cow landed in a clearing at Hawk's first stop, 1284 m from home, with no hit (life 58/58 throughout), and opened its FARP. Once Hawk was gone it lifted off 20 s after the re-task; Viper took it over from 3 km, released it, took it back, and sent it RTB; it despawned on landing 2 m from home, 141 s after the RTB. Hawk never leaves its first stop, so the scenario's step 1 now waits for a FARP more than 1 km from home instead of 2.5 km.
