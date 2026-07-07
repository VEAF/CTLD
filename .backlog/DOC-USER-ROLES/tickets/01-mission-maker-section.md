# 01 — Mission Maker section (EN)

Status: ⬜ ready
Type: AFK

## What to build

The `docs/mission-maker/` section (EN), extracting the **configuration/setup** content from
`docs/missionmaker_guide.md`:

- `index.md` — landing: how to configure CTLD in a mission.
- `configuration.md` — §1 (global settings, `capabilitiesByType` per aircraft).
- `zones.md` — §4 Zone Setup (TRZ / LGZ / EXZ / WPZ naming and setup).
- `scenes-fob.md` — §3 Scene Deployment + §12 FOB.
- `crates-catalogue.md` — `spawnableCrates` config + the config halves of vehicles (§11), AA (§16),
  JTAC (§14).
- `minefield.md` — §8.
- `translations.md` — §2.
- `legacy-api.md` — §9.

Preserve and re-frame existing content (do not rewrite). From mixed sections, take ONLY the
config/setup parts; cross-link to the pilot pages for the in-flight usage. Verify config keys
against `src/` (`ctld.gs`, `capabilitiesByType`, `spawnableCrates`…) and correct drift. "Repack" →
"pack".

## Acceptance criteria

- [ ] All 8 mission-maker pages exist (EN), config-focused, self-contained for that audience.
- [ ] Config keys verified against current `src/`.
- [ ] Cross-links to `../pilot/*` for in-flight usage.

## Blocked by

None.
