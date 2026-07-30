# 05 — fixed-record editor for `spawnableCratesModels`

**Status:** ready

Depends on: lot B ticket 04 (the dead `category` field must be gone, or the editor would expose it).

## Why

`spawnableCratesModels` falls through to `JsonEditor`. It is different from the other gaps: the set of
top-level keys is **fixed and known** — `load`, `sling`, `dynamic` — so no row can be added or removed.
Only values need editing. Lower complexity than `aiZones`: no nested maps.

The three keys are the transport modes, resolved by `_crateModelKey`
([CTLD_crate.lua:1636](../../../src/CTLD_crate.lua#L1636)): `sling` when slingload is on, `dynamic` for a
DCS-dynamic-cargo-capable transport, `load` otherwise.

## What changes

A lightweight fixed-record editor — three hard-coded rows, one per mode — or `RecordListEditor` in a
read-only-rows mode, whichever is less code. Fields per row, after lot B removes `category`:

| Field | Control | Read by |
|---|---|---|
| `type` | text | `data.type`, default `ammo_cargo` |
| `canCargo` | checkbox | `data.canCargo` |
| `shape_name` | text, optional | `data.shape_name`, only set when present — `sling` uses it today |

All three are consumed by `_spawnStatic` ([CTLD_crate.lua:1713](../../../src/CTLD_crate.lua#L1713)).
`shape_name` must stay **optional**: the engine only sets it when present, and `load` / `dynamic` ship
without it. Writing an empty string instead of omitting it would change the DCS static definition.

Label the three rows in plain language — "carried inside", "slung underneath", "DCS dynamic cargo" — not
by their raw keys. The rows are not addable, so the UI should not show add/remove affordances at all.

## Acceptance

- `spawnableCratesModels` no longer reaches `JsonEditor`.
- No add or remove control is present.
- Clearing `shape_name` omits the key rather than writing `""`.
- Round-trip on the shipped catalogue is byte-identical apart from lot B's `category` removal.

## Tests

- vitest: three rows, no add/remove.
- vitest: emptying `shape_name` omits it from the saved model.
- vitest: `canCargo` round-trips as a boolean, not a string.
