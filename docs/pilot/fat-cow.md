# Fat Cow

A Fat Cow is a CH-47 that lands in the field and becomes a forward refuel and rearm point for other helicopters.
The US Army calls it "a rapidly employed FARP": the Chinook carries its fuel in tanks inside the hold and hands it out on the ground.

DCS cannot pass fuel from one aircraft to another, so CTLD lays out a small FARP next to the cow: an invisible helipad, a fuel depot behind the ramp, a few crates and three soldiers standing by.
The FARP's stock is exactly what the cow carries.
When it is gone, it is gone.

There are two ways to get a cow: fly one yourself, or ask CTLD for an AI one.
Everything is in **F10 → CTLD → Fat Cow**.

## Flying a cow (CH-47F)

1. Land in a logistic zone.
2. Load what you want to carry:
    - **Load**, then a loadout: its crates are set down next to you, to load like any CTLD crate.
      Each loadout carries two 800 gal tanks (4 800 kg of jet fuel) and weapons:

      | Menu | Loadouts |
      |---|---|
      | **Load** (Apache) | 40 Hellfires (25 laser, 15 radar) and 2 400 rounds of 30 mm; 60 Hellfires (38 laser, 22 radar) and 1 200 rounds; 40 laser Hellfires and 2 400 rounds; 60 laser Hellfires and 1 200 rounds |
      | **Load → Russian** | Ka-50: 40 Vikhr and 920 rounds of 2A42 (half HE, half AP), or 60 Vikhr and 460 rounds; Mi-24P: 32 Ataka or 32 Shturm, with 500 rounds of GSh-30 |
      | **Load → Mixed** | 20 Hellfires (12 laser, 8 radar), 20 Vikhr, 1 200 rounds of 30 mm and 460 of 2A42; 20 laser Hellfires, 16 Ataka, 1 200 rounds of 30 mm and 500 of GSh-30 |

      That is 6 400 to 8 200 kg in 5 to 8 crates, what a CH-47F lifts with 80 % of its internal fuel: no need to fill the tanks.
    - or one crate at a time, **Request a crate**: a fuel tank (2 400 kg), 20 laser or 20 radar Hellfires, 1 200 rounds of 30 mm, 20 Vikhr, 16 Ataka, 16 Shturm, 460 rounds of 2A42 HE or AP, 500 rounds of GSh-30, then load it like any CTLD crate.

    The last crate of each kind may be part-full: it holds and weighs only what the loadout puts in it.
    **Unload the Fat Cow crates** empties the hold, to make up another loadout.
3. Fly to where the attack helicopters need you, and land.
4. **Deploy the Fat Cow FARP.**
   The FARP opens a few seconds later and you are told what it holds.
   The crates leave your hold: their content is the FARP's stock now, and your helicopter is lighter.
   A crate loaded through the DCS cargo window with the doors closed stays with DCS and is left out: open the doors and use **Crate Commands → Fit parachute** to hand it over to CTLD first.
5. The other helicopters land next to you and rearm and refuel through their ground crew menu, as on any FARP.
6. Take off whenever you like: the FARP stays open, and you are told its name on the F10 map and what it still holds.
   Fly something else (a CSAR, another load), or go and open another FARP elsewhere: each FARP is on its own.
7. To move it, land within 150 m of it and **Pack the Fat Cow FARP**.
   What is left is set down next to you as Fat Cow crates (full ones, and a part-full last one of each kind); an empty FARP gives none.
   Load them, fly elsewhere and deploy them again, or leave them there for someone else.

**Fat Cow stock** tells you what the Fat Cow crates in your hold hold.
An open FARP stays until a CH-47 packs it, whatever happens to the one that laid it out: shot down, its pilot gone, another pilot in the slot.
Any piloted CH-47 of your coalition can pack it, not only yours.

!!! note "When the stock runs out"
    A helicopter asking for more than what is left gets what is left, and its ground crew answers "Unable to comply".
    A request on an empty FARP gets "We don't have this in stock".

## Asking for an AI cow

Any helicopter pilot whose aircraft is not a cow can **Request a Fat Cow**, on the ground or in the air, and pick its loadout.
An aeroplane has no Fat Cow menu: the cow refuels and rearms helicopters.
A CH-47 takes off from the friendly logistic zone nearest to you, and you are told where it comes from, how far it is and when it should join.

The cow then does what your flight tells it, and nothing on its own:

| Command | What the cow does |
|---|---|
| **Land here** | lands in the clearing nearest to a point about 120 m to your left (within 300 m, as far from trees and buildings as it can, never closer than 60 m to you) and opens its FARP one minute after touching down |
| **Take off** | packs its FARP, lifts off and orbits where it stands |
| **Hold here** | packs its FARP if needed and orbits over your position |
| **Join us** | packs its FARP if needed and follows your flight |
| **RTB** | packs its FARP and flies back to base, where it disappears |
| **Release the Fat Cow** | leaves your flight and stays where it is, for another flight to take over: on the ground its FARP stays open, in the air it orbits there |

So you can lift off to hover-taxi onto its FARP, or reposition, without the cow leaving.

**Fat Cow status** tells where your flight's cow is (phase, distance and bearing), when it should join, and what it still holds, before it has landed too.

**Request a Fat Cow** opens the list of loadouts, the same as a piloted cow's (Apache at the top, **Russian** and **Mixed** one level down): pick what your flight needs.
It is always a CH-47, whatever you fly.
One cow per flight.

### Taking over a free cow

If the flight a cow serves is shot down, or its last player leaves, the cow packs its FARP and flies back to base.
Every helicopter flight of its coalition with no cow of its own is told: where it is from them, where it goes and what it holds.

As long as a cow is flying home, for that reason or after an **RTB**, empty or not, or has been released by its flight (**Release the Fat Cow**, which tells those flights too), they find it in **Fat Cow → Take over a Fat Cow**: one entry per cow, nearest first, with its distance from you (updated every 30 s).
The cow you pick joins your flight and obeys its commands as if you had requested it.
A cow released on the ground packs its FARP before joining you.
An entry goes away once its cow is taken over, has landed at its base, or is shot down.

!!! tip "Land in the open"
    The cow looks for a clearing near the point 120 m to your left, but it can only search within 300 m: in a forest, pick open ground for **Land here** anyway.

## What a FARP still holds

**FARP status**, in the same menu, tells what the Fat Cow FARP you are at still holds (the nearest one within 2 km), whoever it belongs to.
