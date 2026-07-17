Status: 🚫 wontfix

# 03 — Validate vehicleStock typeNames at zone-load time

## What to build

CTLD currently passes vehicleStock keys to `coalition.addGroup()` without any validation.
When a key is not a valid DCS typeName, DCS silently substitutes Leopard-2 — no Lua error,
no CTLD log. Mission makers have no feedback.

## Why not implemented

`Unit.getDescByType(typeName)` does not exist in the DCS Lua API — calling it raises
`attempt to call field 'getDescByType' (a nil value)` and crashes the init.

The proper fix requires a shared type registry (`CTLDTypeCollector`, datamine-backed) that
is being built in the `ASSET-VALIDATION-REVAMP` lot. The validation of `vehicleStock`
typeNames should be deferred to that lot and done via the same mechanism as crate/troop
type validation.

Bug 2a (replacing the invalid `M1025 HMMWV Armament` example with `M1045 HMMWV TOW`)
mitigates the immediate problem. The deeper guard is out of scope until
`CTLDTypeCollector` exists.

## Blocked by

`ASSET-VALIDATION-REVAMP` (provides the type registry needed for a safe static lookup).
