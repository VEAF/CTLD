# 02 — Core: a cow's stock, its scene, deploy and pack

**Status:** 🔄 in-progress · **Type:** AFK

## Parent

[PRD — FEAT-FAT-COW](../PRD.md). Decisions 2, 3; ticket 01 answers.

## What to build

- A `CTLDFatCow` entity (Manager + Entity, `src/core/class.lua`) holding a **stock**: fuel in kg and weapons by warehouse item name (`weapons.missiles.AGM_114K`, the 30 mm item), and a state: `stowed` (on board), `deploying`, `deployed`.
- A `CTLDFatCowManager` singleton keyed by cow unit name.
- A **Fat Cow scene** (`src/scenes/CTLD_fatCowScene.lua`): an Invisible FARP at the cow, a `FARP Fuel Depot` 25 m behind it (the only supplier needed, ticket 01), a few ammo crates and barrels as dressing, 3 standing infantry. No vehicle, no tent, no ammo dump, no bunker.
- **Deploy**: plays the scene; on its last step, sets the FARP warehouse to the stock (jet fuel = stock fuel, every other liquid 0, each stocked item to its count).
- **Pack**: reads the FARP warehouse back into the stock (what the players took is gone), then removes the scene.
- **Re-sync**: on every player birth, each deployed cow re-writes its warehouse with the values the server holds (read, then write): ticket 01 did not measure the client side, and VMCT re-applies on birth for that reason. Costs nothing if DCS already syncs.
- Fix the countryside scene's step 11 comment: an Invisible FARP does have a warehouse (measured).

## Acceptance criteria

- [ ] Busted: deploy writes the stock into the warehouse; pack reads the remainder back; a stock emptied by players reads back as empty; re-sync writes back what the server holds; the scene spawns no vehicle and includes a `FARP Fuel Depot`.
- [ ] Scene assets pass the design-time asset gate.
