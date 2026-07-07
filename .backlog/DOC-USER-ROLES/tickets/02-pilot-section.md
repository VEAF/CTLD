# 02 — Pilot section (EN)

Status: ⬜ ready
Type: AFK

## What to build

The `docs/pilot/` section (EN), extracting the **in-flight F10 usage** content from
`docs/missionmaker_guide.md`:

- `index.md` — landing: how to operate CTLD from the cockpit.
- `troop-transport.md` — §5 operational cycle + F10 actions.
- `crates.md` — §10 Actions (load / drop / unpack / list / pack).
- `vehicles.md` — §11 Actions (request / load / pack).
- `slingload.md` — §7 virtual sling-load usage.
- `parachute.md` — §6.
- `jtac.md` — §14 Actions (request / spawn / operate).
- `recon.md` — §15.
- `beacons.md` — §13 + §19 Beacon Layer.
- `smoke.md` — §17.
- `pack.md` — §18 Pack Equipt (vehicle pack & FARP pack workflow).

Preserve and re-frame existing content. From mixed sections, take ONLY the pilot-facing F10
actions; cross-link to `../mission-maker/*` for the setup/config. Verify F10 menu paths and action
names against `src/` (`CTLD_menu.lua`, the manager action methods) and correct drift. "Repack" →
"pack".

## Acceptance criteria

- [ ] All 11 pilot pages exist (EN), usage-focused, self-contained for that audience.
- [ ] F10 menu paths / action names verified against current `src/`.
- [ ] Cross-links to `../mission-maker/*` for configuration.

## Blocked by

None (can run alongside 01; both read the same source, extracting different halves).
