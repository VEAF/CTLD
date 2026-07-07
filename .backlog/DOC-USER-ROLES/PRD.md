# Lot DOC-USER-ROLES — split the user guide by role

Status: 🚧 in progress
Branch: feature/doc-user-roles → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

## Problem Statement

`docs/missionmaker_guide.md` is a 2062-line, 19-section monolith that mixes two very different
audiences:

- **Mission makers** — who configure CTLD in the Mission Editor and the config file (aircraft
  capabilities, zones, `spawnableCrates`, scenes, FOB, minefield, translations, legacy API).
- **Pilots** — who operate CTLD in the cockpit through the F10 menu (troop transport, crate ops,
  vehicle ops, sling-load, parachute, JTAC, recon, beacons, smoke, pack).

Many sections carry both a "setup/config" half and an "Actions" (F10 usage) half, so neither
audience gets a clean, self-contained guide. There is no `docs/pilot/` section, and the nav has a
single flat "Mission Maker" entry.

## Solution

Split the monolith by role into two bilingual (EN + FR) multi-page sections, reorganising the
**mixed sections by subsection**: configuration content → `docs/mission-maker/`, in-flight F10
actions → `docs/pilot/`, with cross-links between the two. Content is preserved and lightly
re-framed (not rewritten); config keys and F10 menu paths are verified against current `src/` and
corrected for drift. The monolith is removed once migrated.

## Scope

`docs/mission-maker/` (Mission Editor + config file):

| Page | Source (missionmaker_guide.md) |
|------|--------------------------------|
| `index.md` | landing / how to configure CTLD |
| `configuration.md` | §1 Configuration (global settings, `capabilitiesByType` per aircraft) |
| `zones.md` | §4 Zone Setup (TRZ / LGZ / EXZ / WPZ) |
| `scenes-fob.md` | §3 Scene Deployment + §12 FOB |
| `crates-catalogue.md` | `spawnableCrates` + vehicle (§11) / AA (§16) / JTAC (§14) config halves |
| `minefield.md` | §8 |
| `translations.md` | §2 Translations & Localisation |
| `legacy-api.md` | §9 Legacy API compatibility |

`docs/pilot/` (in-flight F10 usage):

| Page | Source (missionmaker_guide.md) |
|------|--------------------------------|
| `index.md` | landing / how to fly CTLD ops |
| `troop-transport.md` | §5 (operational cycle + F10 actions) |
| `crates.md` | §10 Actions (load / drop / unpack / list / pack) |
| `vehicles.md` | §11 Actions (request / load / pack) |
| `slingload.md` | §7 (virtual sling-load usage) |
| `parachute.md` | §6 Virtual Parachute Drop |
| `jtac.md` | §14 Actions (request / spawn / operate) |
| `recon.md` | §15 |
| `beacons.md` | §13 Radio Beacons + §19 Beacon Layer |
| `smoke.md` | §17 Smoke Drop |
| `pack.md` | §18 Pack Equipt (vehicle pack & FARP pack workflow) |

Plus: mkdocs `nav` gets a new **Pilot** tab and a restructured **Mission Maker** section;
`docs/missionmaker_guide.md` removed; cross-links and the DOC-MKDOCS-era broken anchors fixed;
`mkdocs build --strict` clean.

## Decisions (validated with David)

- **Mixed sections split by subsection** — config → mission-maker, F10 actions → pilot, cross-linked
  (not "whole section to the dominant role").
- **Multi-page per role** (one page per theme), consistent with the DOC-TECH `subsystems/` model.
- **Bilingual EN + FR**, authored once the EN structure is locked.
- Content **preserved and re-framed**, not rewritten; config keys / menu paths verified against
  `src/` and corrected for drift; "Repack" → "pack".

## Testing Decisions

- `mkdocs build --strict` clean (EN + FR).
- No `src/` change → no `CTLD.lua` rebuild.

## Out of Scope

- Developer docs (DOC-TECH, delivered).
- Integration-testing / Witchcraft (`recette-procedure.md`) → `DCS-BRIDGE-MCP`.
