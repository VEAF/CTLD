# 03 — AIZ_ naming-convention parser + silent additions

**Status:** ⬜ ready

**Blocked by:** ticket 01 (needs mission selection + zone reading; independent of ticket 02).

## What to build

A parser for the partial `AIZ_<name>_<coalition>_<P|D>_<cargoType-or-aiDropMode>` convention,
recognised by `ctld-tools` only — the Lua engine (`src/CTLD_zone.lua`) is untouched by this
ticket. Parsed strictly left-to-right: `name` (free text), `coalition` (R/B/N), `P` or `D`
(pickup or dropoff), then a 4th field whose meaning depends on the 3rd (`cargoType` T/V/TV if
pickup, `aiDropMode` G/P/GP if dropoff). Anything after the 4th field (e.g. a legacy stock-number
suffix already present in real zone names like `AIZ_depot_B_P_V_10`) is ignored, not rejected.

Reconcile the parsed result against the current `aiZones` config: every matching zone in the
scanned `.miz` with no existing `aiZones` entry gets one created automatically, with the 4 parsed
fields filled in and `troopStock`/`vehicleStock` left absent (not an empty table), applied
silently (purely additive, no data-loss risk).

Also write the ADR for the decision behind this ticket: tool-only naming-convention recognition,
never engine-level — same pattern as `dev/adr/0016-exz-naming-convention.md`, but reaching the
opposite engine-involvement conclusion for a different reason (AIZ_'s per-template/per-type stock
tables don't fit a naming convention; see `dev/roadmap.md`'s "AIZ_" entry and
[CONTEXT.md](../../../CONTEXT.md)'s "Tool-only naming convention" glossary entry for the
already-settled reasoning — don't re-derive it, just document it).

## Watch out

- This ticket does not implement removals or the automatic mtime-triggered re-scan — that's
  ticket 04. A re-scan here only ever adds entries, never removes any.
- Never touch an `aiZones` entry that already exists, whether its complex fields are filled in or
  still blank — this ticket only creates entries that don't exist yet.
- Never touch an entry whose `dcsZoneName` does not match the `AIZ_` pattern — a Mission Maker's
  own freely-named entry is out of scope for this feature entirely.
- Leaving `troopStock`/`vehicleStock` absent (not an empty table) is deliberate: the existing
  "pickup zone missing stock" validation warning is the intended "still needs attention" signal —
  don't invent a new UI marker for this.

## Acceptance

- A `.miz` zone named per the `AIZ_` convention with no matching `aiZones` entry produces a new
  entry with `dcsZoneName`, `coalition`, pickup-or-dropoff, and the 4th field all filled in from
  the parsed name, and no stock fields.
- A zone name with a trailing suffix after the 4th field (e.g. `_10`) still parses the first 4
  fields correctly.
- A zone name that doesn't match the convention, or a zone matching an already-existing
  `aiZones` entry, produces no change.
- `dev/adr/00NN-<slug>.md` documents the tool-only decision.

## Tests

`web/src/lib/AiZonesEditor.test.ts` (vitest + testing-library/svelte): parser unit cases (valid
forms for each field, trailing-suffix tolerance, malformed/non-matching names) and reconciliation
cases (new entry created with correct fields and absent stock; existing entry untouched;
non-matching name untouched) — same style as the file's existing tests.
