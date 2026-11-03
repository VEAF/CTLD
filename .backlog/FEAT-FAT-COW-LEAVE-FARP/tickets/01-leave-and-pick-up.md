# 01 — loadouts on the ground, FARP left open, packed into crates on the ground

Status: ready

See the [PRD](../PRD.md).

## Where

`src/CTLD_fatCow.lua`: `loadLoadout` (crates set down with `spawnCratesAligned`, partial content and mass kept, instead of `loadIntoHold`), `deployFromHold` (crates consumed), `packIntoHold` (becomes a pack into crates on the ground at the FARP), `onTakeoff` / `onDead` / `onBirth` (no pack for a piloted FARP), `_farpNameFor` / `_releaseFarpName` (one name per open FARP), the cow menu section (the pack command offered near an open FARP). Today an open piloted FARP is a `CTLDFatCow` keyed by the helicopter's unit name, with `cow.crates` still on board: that key and those crates are what this ticket changes. Check that a partial crate's `metadata.fatCow` and `metadata.massKg` survive a ground spawn and the CTLD load (`loadCrate`).

## Acceptance

- A loadout sets its crates next to the helicopter, partial last crate included, and puts nothing in the hold; once the pilot has loaded them, deploying gives the loadout's stock.
- Deploying takes the cow crates out of the hold; the helicopter's mass drops by theirs.
- Taking off, the CH-47 leaves the FARP open and its pilot is told so, with what it holds; the FARP serves the next helicopter landing on it.
- The FARP stays open, its stock intact, when the CH-47 is destroyed, its pilot leaves, or another pilot takes the slot.
- Any piloted cow of the coalition landed within 150 m of an open FARP gets "Pack the Fat Cow FARP": what is left is set down as cow crates at the FARP, and the FARP's name is freed. Beyond 150 m or in the air, the pack is refused with the reason.
- Those crates, loaded by any CH-47 of the coalition and deployed elsewhere, open a FARP with the stock the first one had left.
- Two FARPs can be open at once.
- The AI cows behave as before (existing specs untouched and green).
