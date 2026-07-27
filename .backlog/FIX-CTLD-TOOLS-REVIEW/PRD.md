# FIX-CTLD-TOOLS-REVIEW — findings from FullGas's manual review of PR #68

## Why

FullGas validated the lot-3 web app by hand after PR #68 was merged and filed a structured report.
Every point was re-verified against the code before acting; this lot fixes what held up.

## Verified findings

| # | Finding | Verdict | Fix |
|---|---------|---------|-----|
| 1 | `loadableGroups` shows one column; JTAC groups look identical, "Single JTAC" looks empty | **Confirmed, and worse than reported** — `jtac` is typed `boolean` in `TROOP_FIELDS` while the data is numeric (`jtac: 1`, `jtac: 2`). It renders as an unchecked box, and *editing it writes `true`/`false` into the user's YAML*. A data-corruption bug, not just a rendering one. | Type it `number` |
| 2 | Setting descriptions show mojibake (`Ã©`) | **Confirmed.** 11 FR descriptions in `src/CTLD_config_schema.yaml` are double-encoded (UTF-8 bytes read as cp1252). Introduced by commit `5e4dc50` (PR #66) — PR #68 only made them visible by rendering FR descriptions. Transport is clean: the API serves correct UTF-8. | Re-encode the 11 strings + a guard test |
| 3 | `aiZones` falls back to the raw JSON editor | **Confirmed, and the cause runs deeper.** The engine reads `ctld.gs("aiZones")` (`CTLD_zone.lua:706`); **nothing reads the `AIZones` key** — verified exhaustively across `src/`, and the legacy monolith has neither spelling. So `AIZones` ships 4 default AI zones that have no effect in game, and PR #68 gave them a dedicated editor, reinforcing the illusion. | Point the editor at `aiZones` (default `[]`) and drop the dead `AIZones` key |
| 4 | `logisticUnits` classified under Crates | **Confirmed.** My first reading — "those are unit names, not zones" — was wrong: a logistic unit *is* a zone, a mobile one. The classification rule is the nature of the object. | Move it to Zones |
| 5 | `nbLimitSpawnedTroops` is an opaque `[0, 0]` | **Confirmed.** Positional by DCS coalition; `CTLD_troop.lua:689` reads `ctld.gs(...) or { 0, 0 }`. | Two named fields, RED / BLUE |
| 6 | `beaconIconColor` is an opaque `[1, 0.5, 0, 1]` | **Confirmed.** DCS RGBA floats, fed to `circleToAll`. | Four named fields + a colour preview, and a description in the schema |

## Deliberately out of scope

- **`maxSlingloadSpeed` default `50` → `26`.** FullGas's reasoning is sound (the value is m/s, so 50 is
  ~180 km/h against a UH-1H sling-load limit near 50 KIAS ≈ 26 m/s). But this changes in-flight
  behaviour, so it is the maintainers' call, not a UI fix. Note for whoever takes it: the
  `CTLD_config_defaults.lua` named in the report no longer exists — since ADR 0011 the only source is
  `src/CTLD_config.yaml`, with `CTLD_config_default_yaml.lua` generated from it by the build.
- The hover-height reference frames: FullGas analysed them and closed the point as no-bug.

## Acceptance

- No editor can write a value of the wrong type into a user's config.
- No mojibake anywhere in the schema, enforced by a test rather than by review.
- Every catalogue key the UI exposes is a key the engine actually reads.
