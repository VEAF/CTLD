# 14 — Units traced from the Lua, not guessed

**Status:** done

## Why

Units were read out of the description text (`Max height (m) …`). That covered 40 of the 80 numeric
settings and nothing for those with no description, so half the numbers rendered bare —
`maxSlingloadSpeed = 50`, unit unknowable. I had listed "author a `unit:` field" as a follow-up
needing someone who knows the engine. David's answer: go read the code.

## Method

Four parallel read-only sweeps over `src/`, one per unit family, each required to report the
**consuming code** (`file:line` + the actual lines) or return INDETERMINATE. The rule throughout: a
setting's *name* proves nothing; only the code that uses the value does. DCS facts leaned on —
`getPoint()` coords and `circleToAll` radii are metres, `timer.getTime()` is seconds,
`getVelocity()` is m/s, `setUnitInternalCargo()` is kg.

Nothing came back indeterminate.

## Result

`unit:` on 66 settings. The remaining 14 have no unit **by design** — counters
(`numberOfTroops`, `aaLaunchers`, the `*_LIMIT_*`), codes (`jtacLaserCode*`, `JTAC_smokeColour_*`),
fractions (`fobDestructionThreshold`, `parachuteInertiaFactor`), a multiplier (`reconIconScale`) and a
DCS font size (`beaconTextSize`). Showing a unit on those would be inventing one.

Sample of the evidence (full detail in the sweep reports):

| Setting | Unit | Proof |
|---|---|---|
| `maxSlingloadSpeed` | m/s | `CTLD_crate.lua:1100-1102` — compared to `math.sqrt(vel.x²+vel.y²+vel.z²)` from `getVelocity()`, no conversion factor anywhere in `src/` |
| `deployedBeaconBattery` | min | `CTLD_beacon.lua:376,575,599,692,812` — `* 60` at every site before hitting the `timer.getTime()` clock |
| `hoverTime` | s | `CTLD_crate.lua:1168-1172` seeded then `- 1` per tick, tick is `timer.getTime() + 1` at `:1060` |
| `groundAglThreshold` | m | `CTLD_utils.lua:2086-2089` — `pos.y - land.getHeight(…)` |
| `maxDistanceFromCrate` | m | `CTLD_crate.lua:1150` via `ctld.utils.getDistance`, 2D over x/z (`CTLD_utils.lua:549-565`) |
| `crateSpacing` | m | `CTLD_utils.lua:1989` — linear step `safeDistance + (i-1) * spacing` fed to a world-coord offset |
| `spawnDistanceInCircle` | m | `CTLD_troop.lua:795-800`, `core/CTLD_objectRegistry.lua:425-428` — magnitude of a radial offset |
| `maxTransportWeight` | kg | `CTLD_troop.lua:1239-1246`, summed against `getWeight()` → `setUnitInternalCargo` |

Plumbing: `Schema.unit()`, `unit` per key on `/api/schema` (untranslated — symbols are
language-independent), `settingUnit(authored, description)` in the frontend prefers it and keeps the
description-scraping as fallback.

## Two fixes the investigation forced

- **`spawnDistanceInCircle` was mislabelled.** Ticket 13 called it "Spawn circle spacing"; the code
  uses it as a **radius** (the arc separation comes from the object count). Now "Spawn circle radius".
- **`maxTransportWeight` gained a description.** `0` is unreadable otherwise; the code proves the
  check is skipped entirely when it is 0 (`if maxW > 0 then`).

## Done when

- Every numeric setting either shows a unit or provably has none.
- Units are identical across languages.
- The engine findings the sweeps turned up are recorded (see `dev/roadmap.md`) rather than silently
  fixed — they are runtime concerns, outside this UI lot.
