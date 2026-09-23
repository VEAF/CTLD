# ADR 0017 — `AIZ_` partial naming convention stays `ctld-tools`-only

**Date:** 2026-09-23
**Status:** Accepted
**Lot:** FEAT-CTLD-TOOLS-AIZ-SYNC, ticket 03

## Context

`AIZ_` zones are `aiZones` config entries: the CTLD engine never parses a zone's DCS name for
them, unlike `TRZ_`/`LGZ_`/`WPZ_`/`EXZ_`, which `CTLDZoneManager` auto-discovers by scanning
`env.mission.triggers.zones` at init (see `CONTEXT.md`'s "Zones" glossary and the `grill-with-docs`
session behind `dev/roadmap.md`'s "AIZ_" entry, formalized as `FEAT-EXZ-AUTODISCOVERY`). That lot's
own ticket 02 (ADR 0016) gave `EXZ_` real engine-level auto-discovery precisely because its shape
— two scalar fields — fits a naming convention; `AIZ_`'s per-template/per-type stock tables
(`troopStock`/`vehicleStock`) do not.

A Mission Maker's own zone-naming habit already encodes the simple, scalar half of an `AIZ_`
entry — coalition, pickup-or-dropoff, cargo type/drop mode — in the DCS zone name itself (e.g.
`AIZ_depot_B_P_V_10`, already present in `Test_CTLDNEXT_01.miz`). Recognising that and pre-filling
`ctld-tools`' `aiZones` editor from it removes a real retyping/drift risk, without revisiting
whether `AIZ_` should become engine-auto-discovered — that question was already asked and
declined by the `EXZ_` grill, for the reason above.

## Decision

`ctld-tools` recognises a **partial** naming convention —
`AIZ_<name>_<coalition:R|B|N>_<P|D>_<cargoType-or-aiDropMode>[_<trailing...>]` — purely as an
authoring shortcut of its own. `src/CTLD_zone.lua` is not touched: the engine keeps reading
`ctld.gs("aiZones")` only, exactly as before this lot. The convention exists to **write** a real
`aiZones` entry (pre-filled, still missing its stock tables), never to be interpreted at runtime.

**Parsing is left-anchored and positional**, not right-anchored like `EXZ_`'s (ADR 0016). `EXZ_`
can anchor on its **last** two `_`-segments because its tail is exactly two fields, nothing after
— `<name>` is then free to contain underscores. `AIZ_` cannot do the same: real zone names already
carry an arbitrary-length trailing suffix *after* the 4th field (the legacy stock-number `_10`
above), so there is no fixed end to anchor on. The trade-off is `<name>` here is constrained to
exactly the second `_`-segment (a single token) — unlike `EXZ_`'s unconstrained `<name>`.

**Reconciliation is additions-only in this ticket.** Every `AIZ_`-matching zone in a freshly
scanned mission with no existing `aiZones` entry for that exact `dcsZoneName` gets one created,
its 4 parseable fields filled in, `troopStock`/`vehicleStock` left absent (not an empty table) so
the existing "pickup zone missing stock" validation warning already signals "still needs
attention". Applied silently — purely additive, no data-loss risk. An entry already present, or a
`dcsZoneName` that doesn't match the convention, is never touched. Orphan removal needs a
confirmation recap and is ticket 04's job, not this one.

## Considered options

- **Engine-level auto-discovery for the scalar fields**, leaving only the stock tables as a
  follow-up config entry (a "config+prefix union"). Rejected: this was the exact idea the `EXZ_`
  grill already weighed and declined for `AIZ_` (`dev/roadmap.md`'s "Précédent de compromis"
  note) — it would always trigger the "missing stock" warning by construction (every
  auto-discovered zone is definitionally still incomplete), and it splits one zone's truth across
  two places (a DCS name partially defining it, a config entry completing it) instead of the
  single `aiZones` source of truth the engine already has.
- **Right-anchored parsing, matching `EXZ_`.** Rejected: `AIZ_`'s trailing content after the 4th
  field is not fixed-length like `EXZ_`'s, so there is no stable anchor point at the end of the
  name to parse from.

## Consequences

- A Mission Maker whose zone names already encode the scalar `AIZ_` fields gets a pre-filled
  `aiZones` entry from `ctld-tools` alone, without retyping facts the name already states — but
  the zone's `name` segment must stay a single token for the convention to parse; a name with an
  extra underscore silently fails to match (ignored, not rejected — the entry is imported when the
  Mission Maker later adds it by hand instead).
- The engine's `_loadAIZonesFromConfig` and its own tests are entirely untouched by this lot.
- `ctld-tools` becomes the one place two zone-naming philosophies coexist by design: an
  engine-parsed convention (`TRZ_`/`LGZ_`/`WPZ_`/`EXZ_`) and a tool-parsed one (`AIZ_`) — a
  developer reading `CTLD_zone.lua` finds no trace of the latter, by design (see `CONTEXT.md`).
