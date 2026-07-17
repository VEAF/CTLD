Status: ⬜ ready
Type: AFK

# 01 — Fix C2 activation guard in `onAILand`

## What to build

In `onAILand`, the C2 virtual-stock path activates on `not physicalLoaded`. This flag is
`false` both when no physical vehicle was found AND when one was found but weight-rejected —
so C2 fires even when a real vehicle was intentionally refused. The C2 block comment already
states the correct intent: "only when no physical vehicle found". Fix the code to match.

Add a `physicalPresent` boolean (declared before the `if okVS then` block, set to `true`
when `#loadables > 0` after type filtering but before weight filtering). Change the C2 guard
to `not physicalLoaded and not physicalPresent`. Rebuild `CTLD.lua` after the change.

## Acceptance criteria

- [ ] When a physical vehicle is present in the pickup zone but exceeds the helo weight limit,
      C2 does not activate: `_aiTransportVehicle[unitName]` remains nil after the landing event
- [ ] When no physical vehicle is present in the pickup zone, C2 activates as before
- [ ] When a physical vehicle is present and within weight limit, C1 loads it and C2 does not
      activate (existing behavior preserved)
- [ ] `CTLD.lua` rebuilt from `src/`
- [ ] `luacheck` clean on modified files

## Blocked by

None — can start immediately.
