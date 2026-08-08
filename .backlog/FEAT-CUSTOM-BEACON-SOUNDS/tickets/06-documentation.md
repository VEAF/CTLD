# 06 — Document the custom sounds

**Status:** todo
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Problem

`docs/mission-maker/ctld-tools.{md,fr.md}` describes editing settings and injecting a mission; the
configuration reference documents `radioSound` as a file name to type. Neither describes choosing a
file, and both would be wrong the day this ships.

## Change

- **`ctld-tools.{md,fr.md}`** — how to choose a sound, that it travels inside the mission, and that
  reopening the mission brings it back. One line on the reserved name, so nobody is surprised by
  `CTLD_beacon_custom.ogg` in the archive.
- **`configuration.{md,fr.md}`** — the two settings restated: what the tool writes, and that typing
  a name by hand still works for a sound added through the Mission Editor.
- **`CHANGELOG.md`** `[Unreleased]` — `src/` changes (the schema ships in the deliverable).

## Acceptance

- [ ] EN and FR say the same thing, FR anchors matching their EN counterparts.
- [ ] No claim about DCS audio formats that has not been verified.
