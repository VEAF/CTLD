# 03 — Nav rewire, remove monolith & fix links (EN)

Status: ✅ done
Type: AFK

## What to build

- Update `mkdocs.yml` `nav`: add a **Pilot** tab (pilot pages) and replace the flat
  `Mission Maker: missionmaker_guide.md` entry with a **Mission Maker** section listing the new
  mission-maker pages.
- Remove `docs/missionmaker_guide.md` (content migrated).
- Fix all broken internal links and content gaps — including the DOC-MKDOCS-era `missionmaker_guide`
  anchor warnings — so `mkdocs build --strict` is clean.
- Fix any repo references to `docs/missionmaker_guide.md` (README, docs home).

## Acceptance criteria

- [ ] `mkdocs build --strict` clean (EN + FR).
- [ ] Nav shows Pilot + Mission Maker sections with the new pages.
- [ ] `docs/missionmaker_guide.md` gone; no dangling references anywhere.

## Blocked by

01, 02 (EN content), 04 (FR pages present for the i18n build).
