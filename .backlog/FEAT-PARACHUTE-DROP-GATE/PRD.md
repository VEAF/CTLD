# FEAT-PARACHUTE-DROP-GATE — `enableParachuteDrop`, a global switch ahead of `canParachuteDrop`

**Status:** 🔄 in-progress (all 5 tickets done; PR pending).

Formalizes the `dev/roadmap.md` entry "Parachutage — garde générale d'activation, prioritaire sur
`canParachuteDrop`" and a `grill-with-docs` session held 2026-09-27 that resolved the question the
roadmap entry had left open ("quels points d'appel côté menu... doivent lire
`enableParachuteDrop`"). See **ADR 0019** for the call-site mechanism decision this PRD builds on.

## Problem Statement

A Mission Maker who wants to disable parachute dropping mission-wide has no single switch to do
it. `canParachuteDrop` (`capabilitiesByType`) is the only gate today, and it's per-aircraft-type:
turning parachuting off for every aircraft means editing every single type's entry individually,
and a newly-added aircraft type defaults to whatever `canParachuteDrop` its own entry carries —
nothing stops parachuting mission-wide by default.

## Solution

A new global setting, `enableParachuteDrop` (default `true` — no behavior change for any existing
mission until a MM explicitly disables it), acts as a first-rank gate ahead of the existing
per-aircraft `canParachuteDrop` capability. When `false`, all three parachute F10 entries —
"Parachute Crates", "Parachute Troops"/"Parachute All", "Parachute Vehicle" — disappear entirely
for every aircraft, regardless of that aircraft's own `canParachuteDrop` value. `canParachuteDrop`
is only consulted at all when the global switch is `true` (second rank), exactly mirroring how a
Mission Maker already reasons about `enableCrates`/`enableSmokeDrop` as master switches ahead of
their own per-feature details.

No error message is shown when an entry is hidden this way — the gate removes the F10 entry, it
never lets it appear only to fail on click.

## User Stories

1. As a Mission Maker, I want a single `enableParachuteDrop` setting that disables parachute
   dropping for every aircraft at once, so that I don't have to edit `canParachuteDrop` on every
   aircraft type individually to turn the feature off mission-wide.
2. As a Mission Maker who leaves `enableParachuteDrop` at its default (`true`), I want every
   aircraft's existing `canParachuteDrop` behavior to stay exactly as it is today, so that
   upgrading CTLD never silently changes which aircraft can parachute-drop.
3. As a Mission Maker who sets `enableParachuteDrop` to `false`, I want the "Parachute Crates",
   "Parachute Troops" (and "Parachute All"), and "Parachute Vehicle" F10 entries to disappear
   completely for every aircraft — including one whose own `canParachuteDrop` is `true` — so that
   the mission-wide switch is a real, unconditional override.
4. As a pilot, I want no error message or dead menu entry when parachute dropping is disabled
   mission-wide — the entry simply isn't there — so that I'm not confused by a command that looks
   available but fails when used.
5. As a developer maintaining CTLD, I want the new global switch checked at exactly the same 5
   call sites that already check `caps.canParachuteDrop` (2 in `CTLD_crate.lua`, 1 in
   `CTLD_troop.lua`, 2 in `CTLD_vehicle.lua`), written inline and consistent with how every other
   capability check in the codebase is already written, so that the fix doesn't introduce the
   first shared capability-predicate helper the codebase has ever had for a single flag (see ADR
   0019 for why that alternative was rejected).
6. As a developer maintaining CTLD, I want the busted coverage that already proves
   `canParachuteDrop=false` hides "Parachute Crates" (F-063/F-064) extended to also prove
   `enableParachuteDrop=false` hides it even when `canParachuteDrop=true`, and I want the
   equivalent coverage — which doesn't exist today — added for "Parachute Troops" and "Parachute
   Vehicle", so that all three domains are proven, not just crates.

## Implementation Decisions

- **New scalar setting `enableParachuteDrop`** in `CTLD_config_schema.yaml`: `group: parachute`,
  `standard: true` (matches every other `enable<Feature>` master switch, which is always
  `standard: true` even when its sibling settings in the same group are advanced-only), inserted
  alphabetically right after `autoUnpackRadiusParachute` and before `parachuteDescentRateCrates`.
  Default `true` in `CTLD_config.yaml`, next to the other `parachute*`/`autoUnpackRadiusParachute`
  entries.
- **No new registration mechanism.** `CTLDPlayerManager:registerMenuSection` only gates a
  top-level section a single manager builds from scratch; parachute drop has no top-level section
  of its own — its three F10 entries live inside "Crate Commands"/"Troop Commands"/"Vehicle
  Commands", sections owned by managers that also own unrelated commands. See **ADR 0019** for the
  full reasoning and the alternatives rejected (generalizing `registerMenuSection`; a shared
  capability-predicate helper).
- **`ctld.gs("enableParachuteDrop")` is added as an inline `and`-condition** at each of the 5
  existing call sites that already check `caps.canParachuteDrop`:
  - `CTLD_crate.lua`: `refreshCrateFlightSection` (visibility toggle) and the build-time
    `menu:addCommand` for "Parachute Crates".
  - `CTLD_troop.lua`: the single "Parachute Troops"/"Parachute All" build site (troops rebuild
    their whole section on every flight-state change rather than toggling visibility separately).
  - `CTLD_vehicle.lua`: `refreshParachuteVehicleSection` (visibility toggle) and the build-time
    `menu:addCommand` for "Parachute Vehicle" in `buildMenuSection`.
  No shared helper function is introduced — every other capability check in the codebase
  (`caps.canSlingload`, `caps.canParachuteDrop` itself, etc.) is already written inline, repeated
  per call site, with no existing precedent for a shared predicate to extend.
- **Menu-visibility gate only** — `enableParachuteDrop` does not touch
  `parachuteCrates`/`parachuteTroops`/`parachuteVehicle` themselves (the manager methods the F10
  commands call), matching how `enableCrates`/`enableSmokeDrop` also only gate menu presence, never
  the underlying action. No scripted/legacy API exposes these actions outside the F10 menu today,
  so there is nothing else to gate.
- **No CHANGELOG entries for the parachute physics settings** (`parachuteMinAltitude*`,
  `parachuteDescentRate*`, etc.) are affected — they simply become irrelevant, not removed, while
  the gate is off.

## Testing Decisions

- Only external behavior is tested — F10 menu node presence/absence for a given
  `enableParachuteDrop`/`canParachuteDrop` combination, not internal call mechanics.
- `tests/ci/functional/parachute_spec.lua`, describe block "F-063/F-064 — canParachuteDrop menu":
  extended with two new cases — `enableParachuteDrop=false` + `canParachuteDrop=true` still hides
  "Parachute Crates" (the global gate overrides the per-type capability); `enableParachuteDrop=true`
  (the default) + `canParachuteDrop=true` still shows it (no regression from adding the new
  setting).
- Same two-case pattern **newly added** for "Parachute Troops" and "Parachute Vehicle" — today
  untested as a dedicated toggle (only incidentally exercised at `canParachuteDrop=true` in
  `menu_gating_spec.lua`/`troop_fastrope_spec.lua`). Prior art for the shape: the existing
  F-063/F-064 pair in the same file.
- No `tools/ctld-tools/tests/` (pytest) impact expected — a new scalar boolean setting with
  `standard: true` renders through the existing generic settings UI with no bespoke editor
  component, the same way every other `enable<Feature>` flag already does.

## Out of Scope

- Generalizing `registerMenuSection` to gate a command nested inside another manager's section —
  considered and rejected in ADR 0019, not built here or anywhere else.
- Any change to the parachute physics settings (`parachuteMinAltitude*`, `parachuteDescentRate*`,
  `parachuteInertiaFactor`, `parachuteLateralDrift*`) — unaffected either way.
- Any change to `canParachuteDrop` itself, or to any aircraft's `capabilitiesByType` entry.
- A shared capability-predicate helper for `caps.canSlingload`/`caps.canParachuteDrop`/etc. — ADR
  0019 explicitly defers this to a future lot if a second or third feature needs the same shape.

## Further Notes

**ADR 0019** (`dev/adr/0019-parachute-drop-global-gate-inline.md`) already documents the call-site
mechanism decision — written during the grill session behind this PRD, ships with this lot's
implementation commit. `docs/mission-maker/configuration.md` / `.fr.md` need a new row for
`enableParachuteDrop` in the "Parachute" settings table (routine doc-sync, not a design decision).
