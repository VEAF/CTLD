# 02 — live check (Zip)

Status: ready

See the [PRD](../PRD.md).

To run in DCS once ticket 01 is merged, with two players or one player changing slot.

1. CH-47 at a logistic zone: "Load" > a loadout with fuel and Hellfires. Expected: the crates appear on the ground next to the helicopter, the hold stays empty.
2. Load the crates with the usual CTLD loading, fly out, land, "Deploy the Fat Cow FARP". Expected: the FARP opens with the loadout's stock, and the hold is empty.
3. Take off and fly 5 km away. Expected: a message says the FARP stays open; the FARP is still on the F10 map.
4. Another helicopter lands on the FARP, refuels and rearms. Expected: it does, and "FARP status" shows the stock going down.
5. Come back with the CH-47, land within 150 m, "Pack the Fat Cow FARP". Expected: crates appear on the ground at the FARP with what is left; the FARP no longer serves.
6. Load those crates, fly elsewhere, deploy. Expected: the FARP opens with the stock packed in step 5.
7. Deploy, then leave the CH-47 slot (or let it crash), and take a second CH-47: land at the FARP and pack it. Expected: the second CH-47 packs it.
