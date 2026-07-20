Status: ready

# 01 — Add `getCenter()` to `CTLDTroopZone` + migrate direct `zone.center` accesses

## What

`CTLDLogisticZone` already has a `getCenter()` method. `CTLDTroopZone` does not — callers
access `self.center` (or `zone.center`) directly throughout `src/`. This ticket adds
`getCenter()` to `CTLDTroopZone` and migrates every direct `.center` access in `src/` to
call `zone:getCenter()` instead.

This is the prerequisite for the lazy `trigger.misc.getZone()` lookup in ticket 02.

## Scope

- Add `CTLDTroopZone:getCenter()` returning `self.center` (simple delegation for now).
- Grep `src/` for `.center` accesses on troop-zone objects and replace with `:getCenter()`.
- Busted test: assert `zone:getCenter()` returns the center passed at construction.
- No behavior change — all zones are still static after this ticket.

## Definition of done

- `CTLDTroopZone:getCenter()` exists and returns `self.center`.
- No direct `.center` field access on zone objects remains outside `CTLDTroopZone` itself.
- Existing busted tests (zone_manager_spec.lua) still pass.
- luacheck clean.
