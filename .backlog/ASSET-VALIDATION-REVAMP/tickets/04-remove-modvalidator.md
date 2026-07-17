# 04 — Remove CTLD_modValidator (the probe) from the deliverable

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Delete the probe. Once the companion (ticket 03) provides the dev-time value with no side effects,
`CTLD_modValidator` has no remaining role in the shipped `CTLD.lua`.

- Remove `core/CTLD_modValidator.lua` from `listToMerge.txt` and delete the file.
- Remove its call sites / references in `CTLD_crate`, `CTLD_troop`, `CTLD_config`, `CTLD_core`
  (grep clean).
- Remove/retool the probe's tests: `tests/ci/unit/modvalidator_spec.lua`,
  `tests/dcs/noPlayer/U-106*`, `U-107*`, `U-108*`.
- Ensure no crate/troop/AA path silently depended on `_disabled`/purge behaviour left by the probe.

## Acceptance criteria

- [ ] `CTLD_modValidator` gone from `src/` and `listToMerge.txt`; no dangling references.
- [ ] No spawn/destroy at mission start attributable to validation (verified via dcs-bridge on a
      clean mission).
- [ ] Probe tests removed or retooled; suite green.
- [ ] Rebuild `CTLD.lua`; busted + luacheck clean; coverage ratchet respected.

## Blocked by

03 (the companion must replace the probe's dev value before the probe is deleted).
