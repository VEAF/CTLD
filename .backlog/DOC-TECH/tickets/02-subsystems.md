# 02 — Subsystems page (EN)

Status: ⬜ ready
Type: AFK

## What to build

`docs/developer/subsystems.md` (EN) consolidating the per-subsystem deep-dives from `dev-guide.md`
and the matching `migration/specs/` files:

- Scene engine (§5) + FARP **pack** flow (rename "Repack" → "pack").
- Crate spawn pipeline (§6).
- Troop + JTAC lifecycle (§11) + `JTAC_lifecycle_analysis.md`.
- Zone management (§12) + `TroopZones_Architecture.md`.
- Vehicle system (§13) + `vehicle_whole_unit_transport.md`.
- Beacon system (§14), Recon system (§15).
- F10 menu system (§16) + `CTLD_Menu_Architecture.md` + `CTLD_Menu_Technical.md` + `F10_menu_tree.md`.
- Player tracking (§17), AA system assembly (§18).

Merge the spec detail into each subsystem so nothing unique is lost (the specs are archived in
ticket 06). **Decision (validated with David):** one page per subsystem under
`docs/developer/subsystems/<name>.md` (`scenes`, `crates`, `troops-jtac`, `zones`, `vehicles`,
`beacons`, `recon`, `menu`, `players`, `aa`), wired as a nav section.

## Acceptance criteria

- [ ] Every subsystem above is covered, merging dev-guide + its spec(s).
- [ ] No "Repack" wording remains; "pack" used throughout.
- [ ] No unique information from the migrated specs is dropped.
- [ ] Diagrams referenced from `docs/assets/`.

## Blocked by

01 (section skeleton).
