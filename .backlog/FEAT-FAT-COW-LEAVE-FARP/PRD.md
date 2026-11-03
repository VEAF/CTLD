# FEAT-FAT-COW-LEAVE-FARP — a piloted Fat Cow leaves its FARP behind, and packs it into crates on the ground

Status: ready

## Problem

A player-flown Fat Cow (FEAT-FAT-COW) is tied to its FARP: the stock stays in the crates on board while the FARP is open, and the FARP packs itself back into the hold the moment the CH-47 takes off (`onTakeoff` → `packIntoHold`), dies (`onDead` → `removeCow`) or a new pilot takes the slot (`onBirth`).

So the CH-47 pilot who sets up a forward point has to sit on it for as long as it serves.
Zip, 2026-11-03: the pilot should be able to deploy the FARP, take off without packing it, fly something else (a CSAR, for instance), and come back later to pick it up and take it elsewhere if needed.

The loadouts also skip the CTLD way of handling cargo.
A single cow crate requested from the menu is set down next to the helicopter (`requestCrate` → `spawnCratesAligned`) and loaded by the pilot, but a loadout (two fuel tanks and 40 Hellfires, say) goes straight into the hold (`loadLoadout` → `loadIntoHold`), with no crate ever on the ground.
Zip, 2026-11-03: a loadout should set its crates down, like CTLD does, for the pilot to load.

## Solution

1. **A loadout sets its crates down.** "Load" > a loadout lays its crates next to the helicopter, a partial last crate keeping its partial content and mass, and says so; the pilot loads them with the usual CTLD crate loading. Nothing goes straight into the hold any more.
2. **Deploying consumes the crates.** "Deploy the Fat Cow FARP" takes the cow crates out of the hold: their content is now the FARP's warehouse, the helicopter is lighter by their mass, and its hold is free for other cargo.
3. **Taking off leaves the FARP open.** No pack on `S_EVENT_TAKEOFF` any more. The pilot is told the FARP stays open, where it is, and what it holds.
4. **The FARP lives on its own.** It is no longer keyed by the helicopter's unit name: it outlives its pilot leaving the slot, the slot changing hands, and the CH-47 being destroyed. It keeps being re-synced like any open cow FARP (`_resyncFarps`), and "FARP status" keeps reporting it.
5. **Packing puts the FARP back into crates on the ground.** "Pack the Fat Cow FARP", from a piloted cow landed close to an open FARP: what is left becomes cow crates set down at the FARP (full crates, a partial last one of each kind; an empty FARP gives none), the scene is removed and the FARP emptied. The pilot then loads the crates by hand and deploys them elsewhere, or leaves them there.
6. **One heliport per FARP, not per unit.** A pilot can open a second FARP elsewhere while the first one still stands: each open FARP gets its own name, and a packed FARP's name goes back to the pool (`_freeFarps`) for the next deployment.

## Decisions

- **Who may pack a FARP: any piloted cow of its coalition** (a `fatCowTypes` helicopter with a player), not only the one that laid it out. Why: the pilot who left it may have disconnected or crashed, and a FARP nobody but a vanished pilot can pack would be stuck on the map. Zip asked for "the same CH-47 coming back"; any CH-47 of the side covers that case and the others.
- **Pack range: within 150 m of the FARP, on the ground**, like the deploy.
- **Packing needs no room in the hold**: the crates go to the ground, and loading them is the usual CTLD crate loading, with its own capacity check.
- **The crates of a packed FARP are ordinary cow crates**: any CH-47 of the coalition may load them, a partial crate deploys with its partial content, and they stay on the ground until someone loads them.
- **An open FARP stays until it is packed**, empty or not, whatever happens to the helicopter that laid it out. No timer.
- **"Unload the Fat Cow crates" at a logistic zone stays** as it is (the crates in the hold go back to the zone).
- **The AI cows do not change.** An AI cow still carries its stock as cargo mass, packs before it moves (`_readyToMove`, `_onAITakeoff`), and the take-over (FEAT-FAT-COW-TAKEOVER) still deals with AI cows only.

## Definition of done

- Unit specs (`tests/ci/unit/`): a loadout sets its crates on the ground, partial last crate included, and puts nothing in the hold; loading those crates and deploying gives the loadout's stock; deploy empties the hold and lightens the helicopter; take-off, death and a new pilot on the slot leave the FARP open and its stock untouched; pack from a CH-47 other than the one that laid it out, within and beyond 150 m, airborne, and with an emptied FARP; the packed crates on the ground carry what the FARP held, and loading and deploying them again gives that stock back; two FARPs open at once under two names, and a packed FARP's name reused; `_resyncFarps` keeps re-writing a FARP whose helicopter is gone.
- Pilot docs (EN + FR): a loadout is set down to be loaded, the FARP stays open after take-off, packing sets the crates down; mission-maker docs say an open FARP outlives its helicopter.
- CHANGELOG `[Unreleased]`, i18n keys in the four dictionaries.
- Live check written for Zip (ticket 02).

## Out of scope

- Packing an AI cow's FARP with a piloted CH-47, or handing a player FARP over to an AI cow.
- Keeping open FARPs, or packed crates, across a mission restart.
- A coalition-wide message when a FARP is left open (the heliport is on the F10 map; "FARP status" reports it on the spot).
