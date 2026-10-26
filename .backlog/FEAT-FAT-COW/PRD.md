# FEAT-FAT-COW — a CH-47 that lands in the field and becomes a forward refuel/rearm point

**Status:** 🔄 in-progress — ticket 01 phase 1 done (2026-10-26): a runtime Invisible FARP serves a player already in game, enforces a finite stock, and needs a supplier in range, which the `FARP Fuel Depot` static alone satisfies, for fuel and weapons, without any vehicle. Phase 2 (a remote multiplayer client) not run: Zip hosted, so his view was the server's; the design re-applies the stock on every birth instead. Implementation in progress (Zip, 2026-10-26: "implémente").

Designed with Zip on 2026-10-26 (VMCT session). Zip decided that the runtime belongs in CTLD, not in the VMCT Lua; VMCT will vendor this CTLD and add a static mission-editing tool for it afterwards.

## Problem Statement

Attack helicopters (typically AH-64D) on a long sortie have to fly back to an airfield or a mission-placed FARP to refuel and rearm.
The US Army answers this with the "Fat Cow": a CH-47 that lands near them and serves fuel from its internal tanks.
Army.mil (Feb 2020) calls it "a rapidly employed FARP" enabling "a quick refuel and rearm" of AH-64s; DVIDS (May 2022) mentions two ERFS tanks of 800 gal.

DCS has no fuel-transfer API, and the CH-47F definition has no fuel-transfer capability.
So the cow can only be a FARP spawned next to it, stocked with what the cow carries.

ED announced a native Fat Cow on 2024-04-19 and again on 2024-08-23; it is absent from DCS 2.9.30.28738.

## Decisions (Zip, 2026-10-26)

1. **Two modes, one core.**
   - **AI:** a cow can be requested only on the ground, inside a friendly CTLD logistic zone. It escorts the requesting flight, lands near it when it lands, and deploys the FARP after **60 s** on the ground. When the flight takes off, it packs the FARP and follows again. It flies back to its logistic zone and despawns when its stock is empty, and also on an F10 "release the Fat Cow" command.
   - **Piloted:** a player CH-47F (`CH-47Fbl1`) loads "cow" crates in a logistic zone: one crate = one 800 gal ERFS tank (about 2 400 kg of fuel, that mass in the hold), plus optional ammo crates (Hellfire, 30 mm). Once landed, an F10 command deploys the FARP, and another packs it.
2. **Materialisation:** an Invisible FARP, a few crates around and 2 or 3 infantry. **No vehicles** (Zip: where would they come from?). Reuses the scene mechanism of `src/scenes/` (`CTLD_countrysideFarpScene.lua`, `CTLD_farpScene.lua`).
3. **Stock = what the cow carries**, as a finite FARP warehouse, not unlimited. **AI default: full fuel (3 × 800 gal, about 7 200 kg) and 6 Hellfires**, configurable in the CTLD config. The 6 is Zip's call: no source gives the Hellfire load of a cow.
4. **Ticket 01 is an in-game spike, before building the rest.** If an answer kills the design, stop and report to Zip.

## What the spike must settle, and why it is not obvious

- `src/scenes/CTLD_countrysideFarpScene.lua` contradicts itself: its header says the Invisible FARP "creates a proper DCS airbase (warehouse…)", its step 11 says "Invisible FARP airbases (DCS built-in) return nil for getWarehouse()". The finite stock of decision 3 needs a warehouse.
- VMCT refills FARP warehouses on every player birth (`veafGrass.fillFarpWarehouse`) because warehouses do not sync over the network, and an ED forum guide (2024) says dynamically spawned FARPs start empty and resupply badly by script.
- RotorOps PERKS does not spawn its Fat Cow FARP: it teleports FARP statics pre-placed in the Mission Editor (`RotorOpsPerks.teleportStatic`), and skips the deployment when enemies are within 1.1 nm, because DCS refuses to rearm/refuel there. Both are hints that a runtime FARP is fragile.
- DCS historically needed a fuel truck and an ammo truck near a FARP. Decision 2 has none; if DCS still needs them, the fallback is a vehicle hidden under the cow's fuselage.

## Design (to be confirmed by the spike)

- **Core:** a `CTLDFatCow` entity (Manager + Entity pattern) holding a stock (fuel kg, items by warehouse name) and a state (`flying`, `landed`, `deployed`, `packing`, `returning`). Deploy = run the cow scene next to the cow, then set the FARP warehouse to the stock. Pack = read the warehouse back into the stock (what the players consumed is gone), then remove the scene. Empty stock → the AI cow goes home.
- **AI mode** listens to `S_EVENT_LAND` / `S_EVENT_TAKEOFF` of the escorted flight (CTLD already subscribes to these for players and AI transports), and drives the cow with DCS tasks (`Follow`/escort, `Land`).
- **Piloted mode** reuses the crate system: cow crates are crate models whose weight is the fuel mass; the deploy command sums the loaded cow crates into the stock.
- **Config** under one `fatCow` block in `src/CTLD_config.yaml` (adds keys → `configVersion` bump and a catalogue shape, per `CLAUDE.md`).

## Contract for VMCT (draft, fixed when the AI ticket is written)

VMCT will add a CLI + MCP tool that places an AI cow escorting a named flight in a mission. It depends on how this lot declares a cow, so the contract is part of the lot's deliverable and lands in `docs/mission-maker/` (EN + FR):

- **Config keys** (draft): `fatCow.enabled`, `fatCow.aiTemplate` (the CH-47 group CTLD clones for a requested cow), `fatCow.deployDelay` (60 s), `fatCow.aiStock` (`fuelKg` 7 200, `items` with 6 Hellfires), `fatCow.crate` (fuel per crate 2 400 kg), `fatCow.ammoCrates`.
- **A mission-placed AI cow** is recognised by an explicit config entry (`fatCow.aiCows = { { group = "<CH-47 group>", escort = "<flight group>" } }`), not by parsing its name: the engine does not parse names for config-heavy features (see `CONTEXT.md`, "Config-referenced zone"). A tool-only naming convention for VMCT to pre-fill the entry stays possible.

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [In-game spike: a runtime FARP, its finite stock, its vehicles](tickets/01-spike-runtime-farp.md) | 🧑 phase 1 done (a yes, b yes server side, c the FARP Fuel Depot alone suffices, no vehicle); phase 2 to run |
| 02 | [Core: a cow's stock, its scene, deploy and pack](tickets/02-core-stock-and-scene.md) | 🔄 in-progress |
| 03 | [Piloted cow: cow crates in a CH-47F and the F10 commands](tickets/03-piloted-cow.md) | ⬜ ready |
| 04 | [AI cow: requested by a flight, escorts it, serves it, goes home](tickets/04-ai-cow.md) | ⬜ ready |
| 05 | [Config, VMCT contract doc, CHANGELOG and release notes](tickets/05-config-docs-release.md) | ⬜ ready |
| 06 | [Live check in DCS](tickets/06-live-check.md) | ⬜ ready (HITL) |

## Release notes

When the feature ships, the release notes poke fun at ED's native Fat Cow, announced on 2024-04-19 and 2024-08-23 and still absent from DCS 2.9.30.28738.
