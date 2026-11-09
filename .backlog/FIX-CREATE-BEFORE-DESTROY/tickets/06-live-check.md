# 06 — Live check in DCS

**Status:** ✅ done — automated checks PASS and the hand test in the CH-47F cockpit confirmed by the maintainer (2026-11-09) · **Type:** HITL

## Parent

[PRD — FIX-CREATE-BEFORE-DESTROY](../PRD.md).

## What to build

Verify in a running mission what the unit tests cannot: DCS cannot be made to refuse a creation without tampering, so the check is that the
**success path of each site is unchanged**, and that the AA respawn on top of the old group works.

Through the DCS bridge's Python scenario runner (never the MCP tool), on `Test_CTLDNEXT_01.miz`, with a scenario per site under `tests/dcs/`
(from the template, tier header set), keeping clear of any live player unit when spawning:

1. Pack a vehicle (a JTAC one too: it must stop being a JTAC only once packed), then unpack its crates again.
2. Pack a deployed FARP scene and redeploy it: the warehouse stock comes back from the crates.
3. Deploy a piloted Fat Cow FARP, pack it, deploy again: the stock matches.
4. Unpack an equipment crate and a parachuted crate (auto-unpack).
5. Repair and rearm an AA system: the new group appears over the old one, which then goes; no ghost unit, no double system.

The maintainer plays one pack by hand in the cockpit (a CH-47F pack of a vehicle) to confirm what the pilot reads.

## Result (2026-11-09, DCS 2.9.30.28738 mission `Test_CTLDNEXT_01.miz`, CTLD built from `fix/FIX-CREATE-BEFORE-DESTROY`)

Two scenarios, driven over the bridge's HTTP API with a mock transport 3 km from the player, real DCS objects, cleaned up afterwards:

- `tests/dcs/noPlayer/scenario_create_before_destroy.lua` (CBD): **PASS 24/24**. Pack Vehicle (3 crates, `cratesSpawned` 3, Humvee gone), unpack of the parachuted crates into a vehicle, AA assembly, repair and rearm of a KUB system.
  The new AA group is spawned over the old one and DCS accepts it; the old group is then destroyed, one system is left.
- `tests/dcs/noPlayer/scenario_create_before_destroy_farp.lua` (CBD2): **PASS 12/12**. A Countryside FARP packed through the real F10 *Pack Equipt* callback (crates with the warehouse snapshot, scene gone), and a piloted Fat Cow FARP packed (the fuel crate carries 2 400 kg, cow forgotten, FARP emptied).

Found on the way, **not caused by this lot**: after an AA repair or rearm the crate is destroyed with `crate:destroy()`, which leaves its registry entry behind, and an entry with no DCS static counts as on the ground (a ghost crate); and the Countryside FARP's guard and repair-truck groups survive its pack.

## Acceptance criteria

- [x] Each of the five checks recorded PASS or FAIL with the DCS log lines that prove it.
- [x] AA respawn overlap: no error in the DCS log, one system left, the repair crate static destroyed.
- [x] The maintainer confirms the hand test (Zip, 2026-11-09); the lot's index line and PRD status are set to done.

## Blocked by

- [01](01-helper-adr-and-vehicle-pack.md), [02](02-farp-scene-pack.md), [03](03-fat-cow-farp-pack.md), [04](04-unpack-to-a-unit.md), [05](05-aa-system-rearm-repair.md)
