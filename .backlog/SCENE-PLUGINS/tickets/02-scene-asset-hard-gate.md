# 02 — Design-time hard-gate busted test for scene assets

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

A busted test that validates, at dev/CI time, that every DCS type a scene spawns is either in the
vendored datamine set (`tests/data/dcs_types.lua`) or in an optional **per-scene mod whitelist**.
Unlike the existing lenient config linter (`config_types_lint_spec.lua`), this one is a **hard
gate** — an unknown type (neither stock nor whitelisted) **fails** the test.

Collect a scene's spawned types from its `CTLDObjectRegistry` descriptors (the `desc.type` field,
not the registry key). The scene declares its **extra (non-stock) unit types** as a machine-readable
list on the model — `modTypes = { "Farp_FG_Petit_Helipad" }` — which is the whitelist consumed by
this gate. This is **runtime-available metadata** (so the Lot B companion consumes the same union —
one unified concept, see ADR 0007), distinct from `requiresMod = "<human mod name>"` kept for
docs/catalogue. The known set = `dcs_types.lua ∪ model.modTypes`.

All built-in scenes use base-game types already present in the set (verified: Landmine, FARP Tent,
ammo_cargo, Invisible FARP, SINGLE_HELIPAD, outpost, Windsock, Black_Tyre all PRESENT), so the gate
passes for them with an empty whitelist. The whitelist matters for `CTLD_plugins` (Metal FARP's
`Farp_FG_Petit_Helipad`).

## Acceptance criteria

- [ ] Collector resolves each built-in scene's spawned `type` strings via its registry descriptors.
- [ ] Test **fails** on a type absent from `dcs_types.lua ∪ whitelist`; **passes** on stock or
      whitelisted types.
- [ ] All built-in scenes pass (empty whitelist).
- [ ] Whitelist is per-scene metadata, documented as the machine-readable required-mods declaration.
- [ ] Spec is authored so it can be copied ~as-is into `CTLD_plugins` (no CTLD-internal deps beyond
      the registry + the datamine set).
- [ ] Coverage ratchet respected.

## Blocked by

None (the datamine set already exists — DCS-DATAMINE-VENDOR / PR #6).
