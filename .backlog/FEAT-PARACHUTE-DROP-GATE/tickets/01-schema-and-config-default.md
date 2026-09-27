# 01 — Declare `enableParachuteDrop` in the schema, default it to `true`

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

Add `enableParachuteDrop` to `CTLD_config_schema.yaml`: `group: parachute`, `standard: true`,
inserted alphabetically right after `autoUnpackRadiusParachute` and before
`parachuteDescentRateCrates`, with an EN+FR `label`/`description` describing it as the mission-wide
switch ahead of each aircraft's own `canParachuteDrop`.

Add `enableParachuteDrop: true` to `CTLD_config.yaml`, next to the other
`parachute*`/`autoUnpackRadiusParachute` entries.

## Watch out

- `standard: true` is required even though the other `parachute` group entries (physics settings)
  carry no `standard:` key at all — this matches every other `enable<Feature>` master switch
  (`enableCrates`, `enableSmokeDrop`, etc.), which are always `standard: true` regardless of their
  group's other entries' tier.
- Default must be `true` — this ticket must not change behavior for any existing mission; only a
  Mission Maker who explicitly sets it to `false` sees any difference, and only once tickets 02-04
  land.
- This ticket does not add any `and ctld.gs("enableParachuteDrop")` check anywhere in `src/` —
  that's tickets 02, 03, 04. Declaring the setting alone has no runtime effect yet.
- Run `merge_CTLD.ps1` (auto-syncs i18n dicts) after this change, same as any schema/config edit.

## Acceptance

- `CTLD_config_schema.yaml` declares `enableParachuteDrop` with `group: parachute`,
  `standard: true`, EN+FR label and description.
- `CTLD_config.yaml` declares `enableParachuteDrop: true`.
- `ctld.gs("enableParachuteDrop")` resolves to `true` when unset in a `configUser` (ADR 0011
  Addendum 1's default-resolution path), consistent with every other parameter.
- `tests/ci/data/config_defaults.json` (or the fixture `busted` reads defaults from) reflects the
  new key if it's generated/checked against the schema — confirm via existing config-defaults test
  before assuming no fixture update is needed.

## Tests

`tests/ci/unit/` — extend whichever spec already asserts the shape of `config_defaults`/schema
completeness (the same one `FEAT-CONFIG-PARAM-SEMANTICS`'s completeness rule exercises) to cover
the new key resolving to `true` by default. No behavior test yet — that's tickets 02-04.
