# Pack

Packing is the reverse of unpacking: it takes something you already put on the ground — a
deployed vehicle or a whole FARP scene — and turns it **back into crates** so you can load them
up and fly the whole thing somewhere else. Set down the wrong FARP in the wrong valley, or need
to relocate a SAM you deployed an hour ago? Pack it, carry it, unpack it at the new site.

Everything lives in one place: **F10 → CTLD → Crate Commands → Pack Equipt**. That submenu is
built for you on the fly and only shows up when packing is actually possible.

!!! note "When does Pack Equipt appear?"
    The submenu is **ground-only** — it is absent while you are airborne. On the ground, it only
    appears when you are a crate-capable transport aircraft **and** there is at least one
    packable item within range. If you land and see no **Pack Equipt** entry, there is nothing
    nearby to pack (or your mission has both packing options switched off).

## Packing a vehicle

Any ground vehicle you deployed through CTLD — from a crate unpack or from **Request
Equipment** — can be folded back into crates.

1. **Land near the vehicle.** You must be on the ground and within
   `maximumDistancePackableUnitsSearch` — **200 m** by default — of the vehicle.
2. Open **F10 → CTLD → Crate Commands → Pack Equipt**. Each packable vehicle in range is listed
   by name (e.g. the vehicle's crate description).
3. **Select the vehicle.** It is removed from the map and its crates spawn next to you —
   in front of a helicopter, or behind a C-130 / Il-76 that uses native cargo.
4. Load the crates and fly them to the new site, then unpack as usual.

The number of crates that appear matches how many that vehicle needs (`cratesRequired`) — a
heavy unit comes back as several crates, just as it took several to build. You get a
confirmation message: *"… packed into N crate(s)."*

!!! tip "Only CTLD's own vehicles pack"
    Pack Equipt lists only vehicles CTLD spawned and is tracking, and only while they are idle
    (not tasked). Arbitrary map units, scenery props and guards never show up — so the menu
    stays clean.

## Packing a FARP

A deployed FARP scene can be packed the same way, and CTLD **remembers its fuel** while it
travels.

1. **Land within 300 m** of the deployed FARP.
2. Open **Pack Equipt**. A repackable FARP shows up as **Pack [FARP name]**.
3. **Select it.** CTLD snapshots the FARP's warehouse fuel levels, removes the scene, and spawns
   its crates next to you. You get *"FARP packed successfully!"*.
4. Fly the crates to the new location and unpack. The FARP redeploys **with its fuel restored**
   to the captured quantities.

!!! note "Stay on the ground"
    If you trigger a FARP pack while airborne, CTLD refuses and tells you to be on the ground
    first. Only FARP types the mission set up as repackable can be packed — see the Mission
    Maker guide below.

## Turning it off

Both halves of Pack Equipt are on by default and controlled independently by the mission:

| Setting | Default | Controls |
| --- | --- | --- |
| `enablePackingVehicles` | `true` | Whether vehicles can be packed back into crates |
| `enableFARPRepack` | `true` | Whether deployed FARP scenes can be packed |
| `maximumDistancePackableUnitsSearch` | `200` | How close (m) you must be to a vehicle to pack it |

If both `enablePackingVehicles` and `enableFARPRepack` are off, the **Pack Equipt** submenu
never appears.

## See also

- [Crates](crates.md) — spawning, loading, dropping and unpacking the crates you get back.
- [Vehicles](vehicles.md) — requesting and deploying the vehicles you can later pack.
- [Configuration](../mission-maker/configuration.md) — enabling packing and tuning the search
  distance.
- [Scenes & FOBs](../mission-maker/scenes-fob.md) — making a FARP repackable and how fuel is
  captured and restored.
