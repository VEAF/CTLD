# FEAT-FARP-TROOP-PICKUP

**Status:** ✅ done

Grilled 2026-08-26, directly following `FIX-FOB-TROOP-PICKUP` (PR #136, merged) which reconnected
`troopPickupAtFOB` to the F10 troop-pickup path. Mid-grill, the same question was asked for the
FARP ("does this justify the generic zone-link system?") — resolved **no**: the FARP case turns
out simpler than the FOB, not harder, so the deferred `dev/roadmap.md` idea "Lien générique zone ↔
objet de référence" stays deferred, untouched by this lot.

## Problem Statement

A mission maker who deploys a scripted FARP (via a crate-built scene: `farpScene`, `FARP Alpha`,
or `Countryside FARP`) cannot let players embark troops there. Unlike the FOB — which now grants
troop pickup automatically once built, when `troopPickupAtFOB` is on — a built FARP has no
equivalent capability at all: no setting, no mechanism, nothing. A pilot who lands at a
freshly-built FARP with troops to deliver, or wanting to pick some up, finds no "Load Troops" F10
entry there, with no indication this is expected or how to get it.

## Solution

A new setting, `troopPickupAtFARP` (default `true`, mirroring `troopPickupAtFOB`'s role exactly —
a pure on/off guard, nothing else), makes every built FARP register a troop pickup zone the moment
its scene completes — discovered by the F10 menu through the exact same `CTLDZoneManager`
machinery as a Mission-Editor `TRZ_…` zone or a built FOB. The zone is removed automatically the
moment DCS considers the FARP destroyed. No mission-maker script, no per-FARP setup: it works the
same way, automatically, for all three FARP scene variants.

## User Stories

1. As a mission maker relying on the default `troopPickupAtFARP: true`, I want troops to be
   embarkable at any FARP my coalition builds, the same way they already are at a built FOB, so
   that FOB and FARP behave consistently without extra configuration.
2. As a mission maker who sets `troopPickupAtFARP: false`, I want FARPs to grant no troop pickup
   at all, so that I can use FARPs as pure rearm/refuel points without also creating an unwanted
   troop-pickup capability.
3. As a mission maker, I want the troop-pickup radius at a FARP to be tunable independently of the
   FOB's own radius (`farpTroopPickupRadius`, not a reuse of `fobTroopPickupRadius`), so that I can
   size it to a FARP's tighter or looser layout without also affecting every FOB in the mission.
4. As a pilot flying a transport near a built FARP, I want the "Load Troops" F10 entry to appear
   there exactly as it does at a TRZ_ zone or a FOB, so that I don't need to know a FARP is a
   structurally different case under the hood.
5. As a pilot, I want the FARP's troop-pickup point to disappear the moment DCS considers the FARP
   destroyed, so that I never see a "Load Troops" option for a FARP that's gone.
6. As a mission maker, I want this to work identically for all three FARP scene variants
   (`farpScene`, `FARP Alpha`, `Countryside FARP`), so that my choice of FARP type doesn't
   silently gate whether troop pickup works.
7. As a CTLD contributor, I want this feature to reuse `CTLDZoneManager:registerFOBAsTroopZone`/
   `:unregisterTroopZone` exactly as `FIX-FOB-TROOP-PICKUP` left them, so that a FARP-sourced zone
   automatically inherits the existing collision guard (refuses rather than silently overwriting a
   same-named zone) and the correct F10 label (the FARP's own name, not a fabricated `TRZ_…`
   prefix) with zero new code in either place.
8. As a CTLD contributor, I want FARP destruction detected without inventing a new lifecycle
   mechanism, so that this lot stays a narrow reuse of existing, already-proven building blocks
   rather than a second bespoke manager alongside `CTLDFOBManager`.

## Implementation Decisions

- **New settings**, both in the existing `troops` schema group, next to `troopPickupAtFOB`/
  `fobTroopPickupRadius`:
  - `troopPickupAtFARP` — boolean, default `true`. Pure guard, configures nothing else (matches
    `troopPickupAtFOB`'s exact role). Default `true` for FOB/FARP consistency — a deliberate
    departure from the "new capability defaults off" instinct, decided explicitly by the user.
  - `farpTroopPickupRadius` — number, default `150`. Independently tunable from
    `fobTroopPickupRadius` (verified sufficient against all three scenes' physical footprints:
    `farpScene` ~35 m, `FARP Alpha` ~130 m, `Countryside FARP` ~40 m — 150 m comfortably covers
    all three with landing-approach margin).
- **Trigger**: a new final step added to each of the three FARP scene models' `steps` array
  (`farpScene`, `FARP Alpha`, `Countryside FARP`) — no generic `onComplete` hook exists or is
  needed; a scene step is just a `func`, the same pattern `FIX-FOB-TROOP-PICKUP`'s own trigger
  (the FOB scene's last step) already uses. For `FARP Alpha`, which already ends on a
  completion-message step, the registration lands in its own new step immediately after — one
  concern per step, matching the FOB scene's own convention (message step, then registration step,
  kept separate).
- **Airbase resolution**: `Airbase.getByName(name)` on the name of the spawned "Heliports"-category
  static (`SINGLE_HELIPAD` / `Invisible_FARP`) — an already-proven, in-repo pattern (`FARP Alpha`'s
  own first step already does this to stock its warehouse; `Countryside FARP` already saves the
  same name into `scene._params` for its own later steps). No new resolution logic.
- **Coalition**: `scene._coalitionId`, already set generically for every scene (not FOB-specific)
  from the triggering unit's coalition. Same fallback source `_registerDeployedFOB` already reads.
- **Zone registration**: calls `CTLDZoneManager:registerFOBAsTroopZone(name, point,
  ctld.gs("farpTroopPickupRadius"), coalitionId)` exactly as `FIX-FOB-TROOP-PICKUP` left it —
  keyed by the airbase's own DCS-assigned name (no synthetic counter, unlike the FOB's
  "Deployed FOB #N"). The existing collision guard and `displayName` (F10 label) are inherited
  with zero new code.
- **Destruction detection**: no new manager, no integrity model. A FARP registers as a real DCS
  `Airbase` object (the "Heliports" static-spawn trick), so its destruction is binary and
  DCS-native (`ab:isExist()`) — unlike a FOB, which is a plain pile of statics needing an
  integrity threshold computed across several objects. Reuses `CTLDStaticWatcher` exactly as-is
  (`watch(id, checkFn, onDeadFn)`, already generic, already used for this exact object class today
  by the recon FARP-detection code): `watch("trz_farp_" .. name, function() return ab:isExist()
  end, function() CTLDZoneManager.getInstance():unregisterTroopZone(name) end)`. The watch is only
  registered when `registerFOBAsTroopZone` actually succeeded (i.e. wasn't refused by the
  collision guard) — nothing to clean up otherwise. `CTLDStaticWatcher` already self-removes a
  watched entry before firing its callback, so no manual unwatch is needed anywhere.
- **Watch key namespacing**: `"trz_farp_" .. name`, distinct from recon's own
  `"recon_farp_" .. player .. "_" .. id` keys in the same shared `CTLDStaticWatcher` registry —
  no collision between the two independent watchers on the same underlying Airbase object.
- **No legacy `ctld.xxx()` wrapper**, **no new event published** — same reasoning as
  `FIX-FOB-TROOP-PICKUP`: nothing subscribes to a troop-zone-creation event today.
- **CHANGELOG.md**: an **Added** entry (new capability, not a restored one — unlike the FOB fix).

## Testing Decisions

- **Structure**: extend `tests/ci/unit/scenes_minefields_spec.lua`'s existing
  `describe("FARP Alpha scene structure (F-043)")` and `describe("farpScene structure (F-091 Part
  1)")` blocks with a step-count bump and a "final step is func-only" assertion, matching their
  existing style exactly. Add a new `describe("Countryside FARP scene structure")` block (no
  busted coverage exists for this scene today — `dofile` it the same way the other two are loaded
  at `setup()`).
- **Behavior**: invoke the new step's `func(ctx)` directly with a hand-built `ctx` (mirroring
  `troop_zone_scripted_api_spec.lua`'s `Airbase.getByName` stub pattern), then assert through the
  public `CTLDZoneManager:getTroopZoneAtPoint(point, coalition)` path — never by reaching into
  `_troopZones` — matching the discipline `FIX-FOB-TROOP-PICKUP` established. Cases: zone
  registered when `troopPickupAtFARP=true`; none when `false`; zone removed after driving
  `CTLDStaticWatcher.getInstance():_tick(t)` directly (bypassing the real timer) once the stubbed
  `ab:isExist()` flips to `false`; F10 label shows the FARP's own name (reuses the assertion
  pattern `menu_gating_spec.lua` already has for the FOB case).
- No new test needed for `CTLDStaticWatcher` itself — it is reused unchanged; only the new wiring
  into it is this lot's concern.

## Out of Scope

- The generic `linkZonesToOwner`/`unlinkOwner` owner-triggered zone-link mechanism
  (`dev/roadmap.md`) — deliberately not built here; grilled explicitly this session and rejected
  as premature given the FARP case needed no new lifecycle mechanism at all.
- A `CTLDFARPManager` entity of any kind — not needed; DCS's own airbase semantics plus
  `CTLDStaticWatcher` cover the full lifecycle.
- The "player already standing in the zone gets no F10 menu refresh" gap — pre-existing, affects
  every dynamic zone creation path (`dev/roadmap.md`, "Zones dynamiques — aucun
  rafraîchissement..."), not specific to this lot.
- Any change to `troopPickupAtFOB`/`fobTroopPickupRadius`/`registerFOBAsTroopZone`/
  `unregisterTroopZone` — all reused exactly as `FIX-FOB-TROOP-PICKUP` left them.

## Further Notes

- No ADR: every mechanism this lot uses already exists and is already proven for this exact object
  class (`Airbase.getByName`, `CTLDStaticWatcher`, `registerFOBAsTroopZone`/`unregisterTroopZone`)
  — this lot is pure reuse, not a new architectural decision. Same reasoning
  `FEAT-TROOP-ZONE-SCRIPTED-API` used to skip an ADR.
- Direct precedent: `FIX-FOB-TROOP-PICKUP` (PR #136) for the zone-registration half;
  `CTLD_recon.lua`'s FARP-detection code for the `Airbase.getByName` + `CTLDStaticWatcher` half —
  both already shipped, both verified working in production for this exact object class.
- Roadmap: the entry "TRZ_ automatique — création liée au spawn d'un objet (FOB, FARP, etc.)" in
  `dev/roadmap.md` this lot substantially closes (FOB was closed by `FIX-FOB-TROOP-PICKUP`, FARP by
  this lot) should be marked formalized once this lot exists, per the project's roadmap convention.
