# Minefield

CTLD ships a built-in **minefield** scene. When it is deployed, CTLD spawns real DCS
landmine statics in a staggered (quinconce) pattern in front of the transport unit and,
optionally, draws a bounding quadrilateral on the F10 map to show the extent of the field.

This page covers how the minefield is made available in a mission and how to tune its
behaviour. The in-cockpit actions — unpacking the crate to lay a field, and using the
**Clear Mine Field** menu to remove one — are pilot operations, described in the
[Pilot guide](../pilot/index.md).

## Making it available

The minefield is a self-registering scene: as soon as `CTLD.lua` is loaded it appears
automatically as a **Mine Field Crate** in the F10 **Request Equipment** menu, for both
coalitions, requiring a single crate. You do **not** need to declare it in
`spawnableCrates`. See the [Crate catalogue](crates-catalogue.md) for how crates in
general are listed and requested.

Pilots then request the crate, carry it, and unpack it on the ground; the field is laid
in front of the aircraft along its heading. See the [Pilot guide](../pilot/index.md).

### Default layout

The crate always lays the same fixed field: a quinconce grid computed from
5 mines per full row × 15 rows, starting 20 m ahead of the unit, with 6 m between adjacent
mines and 12 m between rows. Odd rows carry 5 mines, even rows carry 4 offset laterally by
half the column spacing, for a total of 68 mines:

```text
x    x    x    x    x        <- odd row  (5 mines)
   x    x    x    x          <- even row (4 mines, shifted right)
x    x    x    x    x        <- odd row
   x    x    x    x          <- even row
```

## Configuration

Settings are read through `ctld.gs("paramName")` at runtime; you set them in
`CTLD_userConfig.lua` under `_cfg.settings[...]`.

| Setting | Default | Description |
| --- | --- | --- |
| `showMinefieldOnF10Map` | `true` | Draw a bounding quad on the F10 map when a minefield is deployed. Set `false` to keep the field hidden. |
| `demineRadius` | `150` | Maximum distance in metres from a landed player to a minefield centre for that field's **Clear Mine Field** entry to appear in the F10 menu. |

```lua
_cfg.settings["showMinefieldOnF10Map"] = true
_cfg.settings["demineRadius"]          = 150
```

## Advanced: laying a minefield from a script

If you want to place minefields from your own mission logic (rather than by having a pilot
unpack a crate), fetch the scene model and call one of its two layout functions. Both take
a DCS Unit object, which defines the origin and heading of the field, and both return a
success flag plus the array of spawned static objects.

Get the model once:

```lua
local mineField = CTLDSceneManager.getInstance():getModel("mineField")
```

### `setLandMineAuto` — by area and count

Provide the target dimensions and a desired mine count; CTLD computes the best
column/row layout automatically.

```lua
local ok, result = mineField.setLandMineAuto(
    transport,   -- DCS Unit object (origin and heading)
    30,          -- distance (m) from the unit to the first mine row
    50,          -- width (m) — lateral extent of the field
    80,          -- length (m) — forward extent of the field
    40           -- desired number of mines
)
-- The actual count may differ slightly from the request due to quinconce rounding.
-- Use #result for the exact number of mines spawned.
```

### `setLandMine` — explicit grid

For full control over column count, row count and both spacings:

```lua
local ok, result = mineField.setLandMine(
    transport,   -- DCS Unit object
    20,          -- distance (m) from the unit to the first mine row
    5,           -- mines per odd (full) row
    15,          -- number of rows
    6,           -- lateral spacing between adjacent mines (m)
    12           -- forward spacing between rows (m)
)
-- Quinconce total: 8 odd rows x 5 + 7 even rows x 4 = 68 mines
```

### Layout edge cases

| Condition | Behaviour |
| --- | --- |
| 1 mine total | A single mine with a small square F10 marker. |
| 1 mine per row | A straight forward column, no stagger. |
| 2+ mines per row | Full quinconce (staggered) layout. |
