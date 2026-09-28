# 01 — F10 menu refresh on any dynamic troop/logistic zone create/remove

**Status:** ready

**Blocked by:** none — can start immediately.

## What to build

Close the gap where a player already standing on the ground where a dynamic zone just appeared or
disappeared sees no change in their F10 menu until they take off and land again.

- `CTLDZoneManager` already publishes `OnLogisticZoneUpdated` on a logistic zone's dynamic
  add/remove (`registerFOBAsLogistic`, `onDead`). Add an equivalent publish for a **troop** zone's
  dynamic add/remove — every path that creates or removes a `_troopZones` entry outside Mission-
  Editor init discovery (`createTroopZoneAtObject`, `removeExtractZone`, and the future call sites
  from tickets 02/03) publishes it.
- Add a subscriber (reacting to both the existing `OnLogisticZoneUpdated` and the new troop-zone
  event) that, for **every currently-tracked ground transport player**, calls
  `CTLDTroopManager:refreshMenuSection` (troop event) or `CTLDCrateManager:refreshCrateFlightSection`
  (logistic event). No proximity/geometry calculation: both functions already recompute the calling
  player's own zone membership (`isInZone`) internally, so calling them unconditionally for every
  on-ground player is correct and cheap.
- One subscriber mechanism covers both zone families — `CTLDZoneManager` already owns creation/
  removal for both, matching the PRD's decision not to build two parallel mechanisms.

## Watch out

- Don't add any distance/radius computation at the publish or subscribe site — that calculation
  already happens inside `refreshMenuSection`/`refreshCrateFlightSection`. Adding it here would
  duplicate logic and risk disagreeing with it.
- "Currently-tracked ground transport player" means the same population `CTLDPlayerManager:refreshAll`
  already iterates, filtered to players currently on the ground (not flying) — reuse whatever
  in-air/on-ground signal the existing `onLand`/`onTakeoff` refresh call sites already use, don't
  invent a new one.
- This ticket only wires the **existing** creation/removal call sites (`createTroopZoneAtObject`,
  `removeExtractZone`, `registerFOBAsLogistic`, the existing logistic `onDead`). Tickets 02 and 03
  add new call sites later (anchor-death removal, auto-discovery) — they must publish through the
  same event this ticket introduces, not invent their own.
- Mission-Editor **init-time** discovery (`_discoverTRZ`, the equivalent logistic-zone init scan)
  must NOT publish this event or trigger a refresh — no player is tracked yet at that point in the
  boot sequence, and the existing `buildMenu` already reads the fully-discovered zone set for a
  player's first menu build.

## Acceptance

- A `TRZ_` created via `createTroopZoneAtObject` while a tracked transport player is already parked
  inside its radius shows the new "Load"/"Disembark" entries in that player's F10 menu without a
  takeoff/landing.
- A `TRZ_` removed via `removeExtractZone` while a player is standing in it drops the corresponding
  F10 entries immediately.
- The same immediate refresh happens for a logistic zone (`registerFOBAsLogistic` / its existing
  `onDead` removal) — not just for troop zones.
- A player who is flying (not on the ground) when a zone changes is not refreshed immediately (no
  behavior change for the in-air case — the existing landing-triggered refresh still applies).
- Mission-Editor-discovered zones at init produce no spurious event/refresh call.

## Tests

New or extended `busted` coverage (a zone-events spec, or extending the existing menu-gating spec)
stubbing a small set of tracked players (some on the ground, some flying) and asserting
`refreshMenuSection`/`refreshCrateFlightSection` is invoked for the on-ground ones only, after a
simulated zone create/remove call — mirroring `menu_gating_spec.lua`'s existing assertion style
(assert on menu content, not on internal call counts where avoidable).
