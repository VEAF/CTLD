# ADR 0019 — `enableParachuteDrop` gates 5 call sites inline, not via `registerMenuSection`

**Date:** 2026-09-27
**Status:** Accepted
**Lot:** not yet formalized — decided during a `grill-with-docs` session on `dev/roadmap.md`,
"Parachutage — garde générale d'activation, prioritaire sur `canParachuteDrop`"; to-prd/to-issues
follow.

## Context

Every existing `enable<Feature>` global gate (`enableCrates`, `enableSmokeDrop`,
`enableFastRopeInsertion`, `enableHoverSlingload`, `enableFARPRepack`) either hides a whole
top-level F10 submenu via `CTLDPlayerManager:registerMenuSection({key, manager, method,
configKey, order})` — one registration, one `configKey`, the section itself opts in or out — or is
a single early-return guard inside one dedicated action function.

Parachute drop doesn't fit either shape. `canParachuteDrop` (a per-aircraft-type
`capabilitiesByType` flag) already gates three independent F10 commands, each living **inside** an
existing, unrelated top-level section rather than owning one of its own: "Parachute Crates" inside
"Crate Commands" (`CTLD_crate.lua`), "Parachute Troops"/"Parachute All" inside "Troop Commands"
(`CTLD_troop.lua`), "Parachute Vehicle" inside "Vehicle Commands" (`CTLD_vehicle.lua`) —
5 call sites total once each domain's separate build-time (`menu:addCommand`) and refresh-time
(`menu:setBranchEnabled`) check is counted (troops rebuild the whole section on every flight-state
change instead, so it has only one call site). `registerMenuSection` only gates a section as a
whole; it has no hook for suppressing one command nested inside a section it doesn't own.

Separately, no shared "capability predicate" helper exists anywhere in the codebase — every
`caps.canSlingload`/`caps.canParachuteDrop`/etc. check is written inline, repeated at each call
site, in all three managers. There is no precedent to extend.

## Decision

`enableParachuteDrop` is checked as a plain `and`-condition alongside the existing
`caps.canParachuteDrop` check, inline, at each of the 5 existing call sites across the 3 files —
no new registration mechanism, no shared predicate helper. This was a deliberate choice between two
alternatives, not the only option available (see below).

## Considered options

- **Generalize `registerMenuSection` to also gate an individual command nested inside another
  manager's section.** Rejected: the mechanism's whole shape (one `manager`/`method` pair building
  one section from scratch) assumes the gated unit *is* the section; retrofitting it to instead
  suppress one command inside a section another manager builds would mean either a new, differently
  shaped registration mechanism, or forcing Crate/Troop/Vehicle Commands to fragment into
  sub-sections they don't otherwise need — disproportionate to gating 3 commands.
- **Introduce a shared capability-predicate helper** (e.g. a new function consulted at all 5
  sites). Rejected: no such helper exists anywhere in the codebase for any other capability check —
  every `caps.xxx` check is already written inline, repeated across call sites, as an established
  (if repetitive) convention. Introducing the first shared predicate helper for this one flag alone
  would be a new abstraction the codebase doesn't otherwise use, for a single extra clause per site.
- **Inline `and`-condition at each existing site** (the chosen option). Matches the codebase's own
  convention for capability checks; costs one repeated clause across 5 sites instead of one new
  mechanism or one new shared function.

## Consequences

- A future contributor extending or auditing the parachute gate must know to touch **5 sites in 3
  files** (`CTLD_crate.lua` ×2, `CTLD_troop.lua` ×1, `CTLD_vehicle.lua` ×2) — there is no single
  registration point that guarantees all of them stay in sync, unlike `enableCrates`/
  `enableSmokeDrop`'s one-line `registerMenuSection` call. Missing one site would leave that single
  command visible while the global flag is off — the risk this ADR accepts in exchange for not
  building a new mechanism for a single feature.
- If a future feature needs the same shape (a global gate over several commands scattered across
  managers' existing sections, not owning one of its own), revisit whether a shared predicate helper
  or an extended `registerMenuSection` earns its keep at that point — one instance doesn't justify
  the abstraction, a second or third might.
