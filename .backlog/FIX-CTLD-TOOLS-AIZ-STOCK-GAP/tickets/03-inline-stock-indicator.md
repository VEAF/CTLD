# 03 — Inline indicator for a stockless zone in the editor

**Status:** ✅ done

**Blocked by:** none — client-side logic mirroring the same two conditions as ticket 02, not a
round trip to it; can start immediately.

## What to build

`AiZonesEditor.svelte` computes, per zone, the same two conditions as ticket 02's validation
check (troop-cargo pickup with no `troopStock`; vehicle-cargo pickup with no `vehicleStock`) and
renders an indicator in two places for an affected zone: on the zone's own summary heading
(visible while scanning many zones at once) and directly beside the specific affected field's
label (`troopStock`'s or `vehicleStock`'s).

The two cases must read differently — the troop case as a real warning (a zone that plainly won't
work), the vehicle case as a calm, informational note about which of two legitimate modes is
active (physical placement vs virtual stock), not an error.

## Watch out

- The component has no collapse/expand interaction today, and this ticket does not add one — a
  zone's fields are already always fully rendered; the indicator works with that layout as-is.
- This is a self-contained client-side computation from the entry's own fields — it does not call
  `/api/validate` or wait on any network round trip.
- Do not wire this into the existing `ValidationPanel`/`goto`-to-setting navigation — that flow is
  keyed for scalar settings, not individual rows of a table-shaped setting like `aiZones`; a
  Mission Maker seeing this indicator is already looking at the zone it concerns.
- The indicator must disappear the moment the entry is completed (e.g. `troopStock` filled in) —
  it reflects the entry's current state, not a one-time check.
- A dropoff-only entry, or a pickup entry whose cargo doesn't include the relevant type, never
  shows either indicator.

## Acceptance

- A troop-cargo pickup zone with no `troopStock` shows the warning indicator on its heading and
  beside the `troopStock` field.
- A vehicle-cargo pickup zone with no `vehicleStock` shows the informational indicator on its
  heading and beside the `vehicleStock` field — visually distinct from the troop case.
- A complete entry, and a dropoff-only entry, show neither indicator.
- Filling in the missing field removes the indicator immediately, without a page reload.

## Tests

`web/src/lib/AiZonesEditor.test.ts` (vitest + testing-library/svelte), extending the existing
style: the troop-case indicator appears on both the heading and the field for an affected zone;
the vehicle-case indicator likewise, with distinguishable markup/class from the troop case; a
complete entry and a dropoff-only entry show neither; the indicator disappears once the missing
field is filled in.
