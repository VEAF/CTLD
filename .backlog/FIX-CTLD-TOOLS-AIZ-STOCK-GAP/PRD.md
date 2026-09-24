# FIX-CTLD-TOOLS-AIZ-STOCK-GAP — a safe troopStock default, and real visibility for a stockless AIZ_ entry

**Status:** ✅ done (PR #180).

Formalizes `dev/roadmap.md`'s "`ctld-tools` — aiZones : `troopStock`/`vehicleStock` absents,
aucune visibilité ni garde-fou" entry (added 2026-09-24). This PRD does not re-derive the engine
behaviour it cites — `src/CTLD_core.lua:619-663` and `:668-669`, `src/CTLD_zone.lua:275-278` — it
formalizes the conclusions already reached from reading that code.

This is a `ctld-tools` (Python/FastAPI backend + Svelte frontend, `tools/ctld-tools/`) feature. No
`src/` (Lua engine) change is in scope — the engine's own runtime warning
(`src/CTLD_zone.lua:1896-1908`) is a separate, pre-existing mechanism, untouched by this lot.

## Problem Statement

`FEAT-CTLD-TOOLS-AIZ-SYNC` ticket 03 left a silently-added `AIZ_` entry's `troopStock`/
`vehicleStock` absent, on the assumption that "the existing pickup-zone-missing-stock validation
warning" would tell the Mission Maker it still needs attention. That warning does not exist:
`ctld_tools/validate.py` has no check referencing `troopStock`, `vehicleStock` or `aiZones` at
all, and `AiZonesEditor.svelte` renders no icon, badge or warning for it — nor does it collapse a
zone's fields at all (every zone is always fully expanded; there is no dépli/repli interaction to
correct here). The manual "+ AI zone" button has the identical gap: it seeds a new entry with no
stock field whatsoever.

Worse, the two absent fields do not fail the same way. Reading the actual engine code that
consumes them:

- **`troopStock` absent silently disables troop pickup entirely** — no fallback exists
  (`CTLD_core.lua:668-669`: *"troopStock=nil → pickup disabled for this zone"*). A Mission Maker
  who never notices has a pickup zone that will never work for troops, discovered only in flight.
- **`vehicleStock` absent is a legitimate, working mode** — the engine scans for a physical DCS
  vehicle placed in the zone first, independent of any config (`CTLD_core.lua:619-663`, the
  pre-Feature-T mechanic); virtual stock is only a secondary path
  (`CTLD_zone.lua:275-278`). Nothing is broken here, but `ctld-tools` gives no indication of which
  mode a zone is actually in.

## Solution

`ctld-tools` treats the two fields asymmetrically, matching what the engine actually does with
each:

1. A newly created pickup zone whose cargo includes troops (`cargoType` `T` or `TV`) gets a safe,
   working `troopStock` by default — no more silently non-functional zones straight out of either
   creation path (the `AIZ_` naming-convention reconciliation, or the manual "+ AI zone" button).
2. `vehicleStock` is never defaulted — but a zone relying on the physical-placement fallback is
   now clearly marked as such, so it is a Mission Maker's informed choice, not an invisible gap.
3. The same two conditions are also checked server-side at validation time, so a hand-edited or
   otherwise-bypassed configuration is caught before export, not just at the moment of creation.
4. Both conditions are visible directly on the zone in the editor — no digging through a separate
   panel required.

## User Stories

1. As a Mission Maker whose `ctld-tools` scan silently added an `AIZ_` pickup zone for troops, I
   want it to actually work for AI troop pickup without any further action, so that I don't
   discover in flight that a "detected" zone never offered a single soldier.
2. As a Mission Maker clicking "+ AI zone" for a troop-cargo pickup zone, I want the same safe
   default, so that the manual path and the auto-detected path never behave differently for the
   same mistake.
3. As a Mission Maker who deliberately places a physical vehicle in a pickup zone instead of
   configuring `vehicleStock`, I want `ctld-tools` to recognise that as a valid choice rather than
   defaulting a stock table underneath me, so that my own explicit setup is never silently
   overridden.
4. As a Mission Maker looking at a pickup zone with no `vehicleStock`, I want a clear, calm
   explanation that it relies on a physically-placed vehicle rather than virtual stock, so that I
   can decide whether that is really what I meant.
5. As a Mission Maker who hand-edits a YAML configuration outside the two zone-creation paths, I
   want the same two checks caught by `ctld-tools validate`/the pre-export validation, so that a
   configuration that never goes through the UI's own defaults is still caught before it reaches a
   real mission.
6. As a Mission Maker scanning a long list of `aiZones` entries, I want to see at a glance, on the
   zone itself, which ones still need attention, so that I don't have to open and compare every
   single one.
7. As a Mission Maker who has already fixed a flagged zone, I want the indicator to disappear
   immediately, so that the editor always reflects the entry's actual current state.
8. As a developer reading `CTLD_core.lua`/`CTLD_zone.lua`, I want no change to the engine's own
   behaviour or its runtime startup-report warning, so that this lot is understood as a
   `ctld-tools`-side authoring safeguard, not a change to how the mission runs.

## Implementation Decisions

- **Safe default, `troopStock` only**: whenever a new `aiZones` entry is created — by the `AIZ_`
  naming-convention reconciliation's silent-addition path, or by the "+ AI zone" button — and its
  effective `cargoType` includes `T` (i.e. `T` or `TV`), `troopStock` is set to `{All: -1}`
  (unlimited, the same "All" + "-1 = unlimited" convention already used throughout the stock-row
  UI and documented in `docs/mission-maker/zones.md`) rather than left absent. `vehicleStock` is
  never given an equivalent default, for either creation path — its absence is a legitimate,
  working configuration (see Problem Statement), and defaulting it would silently make every known
  vehicle type pickupable there, a far larger behavioural change than the troop case.
- **Both creation paths, one rule**: the same default applies whether the entry came from the
  naming-convention scan or the manual button — a Mission Maker must never see the auto-detected
  and the manually-added path behave differently for the same missing field.
- **Server-side validation, mirroring the engine's own severity choice**: `ctld-tools`' existing
  catalogue-wide validation gains two checks, at `WARNING` severity (not `ERROR` — this matches
  the engine's own runtime message, which is itself a `WARN`, not a startup failure), one finding
  per affected `aiZones` entry:
  - an entry with `isPickup` true, effective `cargoType` including `T`, and `troopStock` still
    nil/empty — reachable in practice only for a hand-edited or otherwise-bypassed configuration,
    since the default above makes it structurally rare through the normal UI paths;
  - an entry with `isPickup` true, effective `cargoType` including `V`, and `vehicleStock` absent
    — worded to explain the physical-placement fallback the engine actually uses, not phrased as
    if something were broken.
  Each finding identifies its own entry specifically (mirroring the existing per-table-entry
  finding shape already used for `spawnableCrates`), so a Mission Maker with several `aiZones`
  entries can tell which one is meant.
- **Client-side, not a round-trip**: the editor computes both conditions itself, from the entry's
  own fields, exactly mirroring the two server-side conditions — it does not wait on a
  `/api/validate` response to show its own indicator.
- **Where the indicator shows**: since a zone's fields are always fully rendered already (there is
  no collapse/expand interaction to add or to hook into — confirmed by reading the component, and
  explicitly not something this lot introduces), the indicator appears in two places at once for
  an affected zone: on the zone's own summary heading (so it is visible even while scanning many
  zones at once) and directly beside the specific field concerned (`troopStock`'s or
  `vehicleStock`'s own label), so a Mission Maker looking at that one zone knows exactly what to
  fix or acknowledge.
- **Two distinct visual treatments**: the troop case is a real functional problem (should read as
  a warning) even though the default above makes it rare; the vehicle case is an informational
  note about which of two legitimate modes is active, not a problem — the two must not look
  identical, or the calm case starts reading as an error the Mission Maker feels compelled to
  "fix".
- **No new navigation machinery**: the existing `ValidationPanel`/`goto`-to-setting flow is keyed
  for scalar settings, not individual rows of a table-shaped setting like `aiZones` — this lot
  does not extend it. The per-zone indicator is sufficient on its own; a Mission Maker is already
  looking at the `aiZones` editor when they see it.

## Testing Decisions

- `tools/ctld-tools/tests/test_validate.py` is the existing seam for `ctld_tools/validate.py` —
  extend it for the two new findings: a pickup zone with troop cargo and no `troopStock` is
  flagged (warning, not error); a pickup zone with vehicle cargo and no `vehicleStock` is flagged
  (warning, worded as informational); a complete entry, and a dropoff-only entry, produce neither
  finding; each finding identifies its own entry.
- `web/src/lib/aizConvention.test.ts` and `web/src/lib/AiZonesEditor.test.ts` are the existing
  seams for the two zone-creation paths and the editor's own rendering — extend them for: a
  silently-added troop-cargo entry gets `troopStock: {All: -1}`; a silently-added vehicle-cargo
  entry gets no `vehicleStock`; "+ AI zone" seeds the same `troopStock` default when its cargo
  includes troops; the indicator appears on the summary heading and beside the specific field for
  an affected zone, and disappears once the entry is completed; the troop and vehicle indicators
  are visually distinguishable from each other.
- Only external behaviour is asserted throughout (the written config shape, the validation
  findings, the rendered markup/text), matching every existing test in these three files.

## Out of Scope

- Any change to `src/` — the engine's own runtime startup-report warning
  (`CTLD_zone.lua:1896-1908`) is untouched, and this lot does not change how the mission behaves at
  runtime in any way.
- A `vehicleStock` default of any kind.
- Building a collapse/expand interaction for a zone's fields — none exists today, and this lot
  does not add one; the indicator is placed to work with the always-fully-rendered layout as it
  already is.
- Wiring the new per-zone indicators into the generic `ValidationPanel`/`goto` navigation flow.
- Re-litigating the `AIZ_` naming convention itself, or the tool-only-vs-engine-level decision
  (ADR 0017) — both stand as already decided.

## Further Notes

- No ADR: this corrects an already-documented decision's false premise and closes the resulting
  gap with a straightforward mechanism extension (a creation-time default plus a validation check
  plus an inline indicator) — not a new architectural trade-off with alternatives to weigh.
- Once this lands, `ADR 0017` and `FEAT-CTLD-TOOLS-AIZ-SYNC` ticket 03's own PRD text describing
  "stock left absent... the existing validation warning doubling as the signal" become
  historically inaccurate for `troopStock` specifically (it now gets a default, not absence) and
  should be read in light of this lot rather than edited retroactively — the implementing ticket
  may add a short note pointing forward to this lot if it touches either file anyway, but rewriting
  history is not the point of this PRD.
