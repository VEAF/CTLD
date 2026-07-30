# 02 — remove `specificParams` from the crate surface

**Status:** done

Depends on: 01. The globals must exist and be rebased first, or this ticket changes how the drones fly.

## What changes

- `src/CTLD_config.yaml`: delete the `specificParams` block from both drone entries
  ([:454](../../../src/CTLD_config.yaml#L454) and [:465](../../../src/CTLD_config.yaml#L465)).
- `src/CTLD_config_schema.yaml`: delete `specificParams` and its four dotted sub-keys from
  `tableFields.spawnableCrates` ([:773-787](../../../src/CTLD_config_schema.yaml#L773)).
- `src/CTLD_crate.lua` [:2259](../../../src/CTLD_crate.lua#L2259) and `src/CTLD_jtac.lua`
  [:726](../../../src/CTLD_jtac.lua#L726): stop passing `desc.specificParams` / `descriptor.specificParams`
  to `startLase`.
- `src/CTLD_jtac.lua`: drop the `orbitParams` parameter threaded through `startLase` / `autoLase` and
  the `CTLDJTAC.orbitParams` field ([:92](../../../src/CTLD_jtac.lua#L92)), now that every value comes
  from a setting. Keep the signatures otherwise stable — `startLase` is called from several places.
- Update the two schema descriptions that name `specificParams` as a fallback source
  ([:289-290](../../../src/CTLD_config_schema.yaml#L289), [:296-297](../../../src/CTLD_config_schema.yaml#L296)):
  the globals are no longer a *fallback*, they are the only source.
- `docs/mission-maker/crates-catalogue.md` + `.fr.md` and `docs/mission-maker/configuration.md` +
  `.fr.md`: remove `specificParams` from the field tables and the example, and reword the
  `JTAC_drone*` rows that describe themselves as fallbacks.
- Rebuild `CTLD.lua`.

## Do not touch

`src/CTLD_troop.lua`. Feature I's `specificParams.task` on `loadableGroups` templates
([:1490](../../../src/CTLD_troop.lua#L1490), and the reads at [:726](../../../src/CTLD_troop.lua#L726),
[:823](../../../src/CTLD_troop.lua#L823), [:870](../../../src/CTLD_troop.lua#L870),
[:1049](../../../src/CTLD_troop.lua#L1049)) is a different feature that happens to share the field name.
The schema never declared it, so nothing here reaches it.

## Acceptance

- `grep -rn specificParams src/` returns only the troop-path sites listed above.
- A drone spawns, climbs, orbits and tightens its orbit on lase exactly as after ticket 01.
- `CHANGELOG.md` `[Unreleased]` records the spawn-altitude change (4000 → 3000 m) as an in-flight
  behaviour change, and names the four settings that replace the per-crate block.

## Tests

- busted: the drone descriptors carry no `specificParams` and still produce a valid orbit.
- busted: a `loadableGroups` template with `specificParams.task` still gets its post-spawn task — a
  regression guard on the boundary between the two features.
