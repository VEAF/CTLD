# 05 — state the reference frame of the hover-height settings

**Status:** ready

Closes `dev/roadmap.md` item 5.

## Why

`minimumHoverHeight` / `maximumHoverHeight` are measured against two different references:

| Site | Measures | Compared to |
|---|---|---|
| [CTLD_crate.lua:1152](../../../src/CTLD_crate.lua#L1152) | `transportPos.y - cratePos.y` — height above the **crate** | `minH`..`maxH` |
| [CTLD_vehicle.lua:1193](../../../src/CTLD_vehicle.lua#L1193) | `tPos.y - vPos.y` — height above the **vehicle** | `minH`..`maxH` |
| [CTLD_crate.lua:1463](../../../src/CTLD_crate.lua#L1463) | `pos.y - land.getHeight(...)` — **terrain AGL** | `maxH` only |

The roadmap flagged this as a possible bug; FullGas closed it as no-bug. **FullGas is right**, and the
roadmap entry should not have survived alongside that verdict.

The difference is inherent, not accidental. The first two sites have a target object to measure
against, and that is the clearance the pilot actually cares about. The third releases a slingload with
no object present, so terrain is the only reference available. And the two checks never apply at the
same moment: the first governs **pickup** (stabilise 7.5–12 m above the crate), the third governs
**release** (be below 12 m AGL). A pilot cannot satisfy one and fail the other for the same crate at
the same time.

What is genuinely at fault is the wording: one setting name spans two reference frames without saying so.

## What changes

- `src/CTLD_config_schema.yaml`: rewrite both descriptions, EN + FR, to state the reference frame per
  use — *"height above the crate or vehicle being picked up; for a slingload release, height above the
  terrain"*. Keep the existing `unit: m` so the extracted unit still shows in the UI.
- `dev/roadmap.md`: **delete** entry 5. Leaving it contradicts the `FIX-CTLD-TOOLS-REVIEW` PRD, which
  already records it as closed.
- No engine change.

## Acceptance

- Both descriptions name both reference frames and which action uses which.
- `dev/roadmap.md` no longer carries the entry.
- No `src/*.lua` change in this ticket.
