# 01 — `parseTRZ` promoted to public

**Status:** ⬜ ready

## Why

The new scripted API (ticket 02) needs the same `TRZ_…` string parsing Mission-Editor discovery
already uses, so the two paths can never disagree on what a given `TRZ_…` name means. Today that
logic lives in `CTLDZoneManager:_parseTRZ`, private by convention (underscore prefix) — nothing
outside `CTLD_zone.lua` is meant to call it.

## What changes

- `CTLDZoneManager:_parseTRZ` renamed to `CTLDZoneManager:parseTRZ` — visibility only, no
  behavior change (same parameters, same return shape: the parsed fields table, or `nil, reason`).
- Both existing call sites updated to `self:parseTRZ(...)`: `CTLDZoneManager:_discoverTRZ`
  (Mission-Editor zone discovery at init) and `CTLDZoneManager:_validateZoneNames` (the
  developer-tool zone-name validator that reports parse errors to the DCS log/screen).
- No other call site exists.

## Acceptance

- Mission-Editor `TRZ_…` zone discovery behaves exactly as before the rename (same zones
  registered, same rejections logged for a malformed name).
- `_validateZoneNames`'s TRZ error reporting behaves exactly as before the rename.
- `CTLDZoneManager:parseTRZ(name)` is callable directly and returns the same shape the old
  `_parseTRZ` did for every existing test case.

## Tests

busted, updating the existing `tests/ci/unit/zone_manager_spec.lua` (23 cases already covering
every valid and invalid `TRZ_…` shape) to call `parseTRZ` instead of `_parseTRZ` — same
assertions, same cases, no new ones needed for the rename itself.
