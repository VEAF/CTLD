# 01 — four JTAC drone globals, rebased on today's values

**Status:** done

> **This ticket contradicted itself, and the contradiction was resolved in favour of the alignment.**
> It demanded that the drones fly "exactly as before" *and* that the hardcoded `speed = 54` m/s in
> `buildGroupUnitDef` be replaced by `JTAC_droneSpeed`. Those cannot both hold: 150 km/h is 41.7 m/s.
>
> The spawn speed was transient — the orbit route overrode it a couple of seconds after spawn — so
> unifying it is the same fix as the altitude, which this lot already celebrates. Both spawn values now
> match the orbit, and both changes are announced in `CHANGELOG.md`. "Exactly as before" is honoured
> where it matters: **the orbit itself is unchanged.**

## Why

`specificParams` carries four orbit values; only two have a global equivalent, and one of those serves
two different radii. Creating the missing globals *before* removing the per-crate values is what keeps
ticket 02 from changing how the drones fly by accident.

## What changes

`src/CTLD_config.yaml`:

| Key | Action | Value | Replaces |
|---|---|---|---|
| `JTAC_droneAltitude` | rebase | 4000 → **3000** | `specificParams.alti` |
| `JTAC_droneRadiusNoLase` | new | **2000** | `specificParams.orbitRadiusNoLase` |
| `JTAC_droneRadiusOnLase` | new | **1000** | `specificParams.orbitRadiusOnLase` |
| `JTAC_droneSpeed` | new | **150** (km/h) | `specificParams.speed` |
| `JTAC_droneRadius` | **remove** | — | superseded by the two radii |

`src/CTLD_config_schema.yaml`: an entry per key with `group: jtac`, `unit` (`m` / `km/h`), bilingual
`label` and a `description` that **states the unit** — the `maxSlingloadSpeed` mistake was an invisible
unit, so every new speed or distance setting says its own. Mark them `standard: true` only if a Mission
Maker plausibly tunes them; orbit geometry is arguably advanced — decide per key, do not blanket-set.

`src/CTLD_jtac.lua` — repoint the reads:

- `_setOrbitRoute` ([:1192-1197](../../../src/CTLD_jtac.lua#L1192)): `speed` → `JTAC_droneSpeed`,
  `alti` → `JTAC_droneAltitude`, and the radius at [:1174](../../../src/CTLD_jtac.lua#L1174) →
  `JTAC_droneRadiusNoLase`.
- `_setOrbitTask` ([:1286-1293](../../../src/CTLD_jtac.lua#L1286)): same, and the radius at
  [:1133](../../../src/CTLD_jtac.lua#L1133) / [:1149](../../../src/CTLD_jtac.lua#L1149) →
  `JTAC_droneRadiusOnLase`.

`src/CTLD_utils.lua` — `buildGroupUnitDef` ([:1305-1306](../../../src/CTLD_utils.lua#L1305)): keep
reading `JTAC_droneAltitude` (now 3000, so spawn and orbit finally agree) and replace the hardcoded
`speed = 54` m/s with `JTAC_droneSpeed` converted from km/h. Leave the `alt_type = "RADIO"` alone.

Do **not** remove `specificParams` here — that is ticket 02. This ticket must leave the drones flying
exactly as before, because the per-crate values still win.

## Acceptance

- With the shipped catalogue, a drone's spawn altitude, orbit altitude, both radii and its speed are
  numerically identical to the current build.
- `JTAC_droneRadius` appears nowhere.
- No speed or distance in `src/` is hardcoded where a setting now exists.

## Tests

- busted: each new global resolves to the value it replaces, so a drift is caught at the source.
- busted: `_setOrbitRoute` / `_setOrbitTask` read the new keys (assert on `ctld.gs` calls or on the
  produced route/task tables).
- busted: spawn altitude equals orbit altitude.
