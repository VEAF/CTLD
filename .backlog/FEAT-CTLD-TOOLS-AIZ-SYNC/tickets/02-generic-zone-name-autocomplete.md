# 02 — Generic zone-name autocomplete on `dcsZoneName`

**Status:** ⬜ ready

**Blocked by:** ticket 01 (needs the zone-listing endpoint).

## What to build

Wire the zone list from ticket 01 into `AiZonesEditor.svelte`'s `dcsZoneName` field as a
`<datalist>`, mirroring the pattern the troop-template stock field a few lines below it already
uses for its own autocomplete. Every real zone name in the tracked mission becomes a suggestion —
independent of the `AIZ_` naming convention (tickets 03/04); this is useful for any zone name.

## Watch out

- This is purely additive to the existing free-text `<input>` — typing a name not in the list
  must still work exactly as it does today (a Mission Maker can always name a zone that doesn't
  exist yet, or one this session hasn't scanned).
- No mission selected yet → the datalist is simply empty; the field stays a plain text input,
  it does not become disabled or show an error.

## Acceptance

- With a mission selected (ticket 01), typing into `dcsZoneName` suggests matching real zone
  names from that mission.
- With no mission selected, the field behaves exactly as it does today.

## Tests

`web/src/lib/AiZonesEditor.test.ts` (vitest + testing-library/svelte): the datalist is populated
from the zone list prop/store; typing still updates the field and fires `onchange` as before.
Only external behaviour (rendered options, the `onchange` payload) is asserted, matching this
file's existing style.
