# FIX-NATIVE-CARRY-DETECTION — make native carry loads and unloads fully tracked by CTLD

**Status:** ⬜ ready.

Formalizes the `dev/roadmap.md` entry "Native-cargo bbox-exit detection is unimplemented" plus a
`grill-with-docs` session (2026-09-29) that widened it: the gap found in the vehicle spawner is one
symptom of a broader inconsistency between **virtual carry** and **native carry** (see the
glossary in `CONTEXT.md`). The decisions below are settled unless a line says "provisional".

## Problem Statement

A pilot flying an aircraft with a native cargo system (C-130J-30, CH-47F, Mi-8MT, UH-1H, Mi-24P)
can carry cargo two ways: through the CTLD F10 menu (**virtual carry**) or through the DCS cargo
system (**native carry**). CTLD tracks the second way only partially, and mixes the two ways in
its menus:

- A whole vehicle that enters a native-carry aircraft is detected and marked `LOADED`, but the
  matching **exit** was never written. The vehicle stays `LOADED` forever after DCS unloads or
  drops it: it cannot be re-loaded, its JTAC stays suspended, no unload event is published, and
  the pilot's F10 lists keep showing it.
- The F10 *Unload Vehicles* and *Parachute Vehicle* entries also list native-carry vehicles.
  Using them on such a vehicle would spawn a duplicate of a unit that is still alive.
- The native entry test for vehicles has no ground or speed guard and no coalition check: a
  taxiing aircraft can "swallow" a parked vehicle, and a BLUE aircraft can load a RED vehicle.
- The native scan walks every airplane group, AI included, and only airplanes. The AI-only Il-76
  can therefore load a parked vehicle "natively", colliding with the virtual logic the AI
  transport already uses. Helicopters with native cargo are never scanned for vehicles.
- The zone used to decide that a vehicle or a crate is "inside" a native-carry aircraft is the
  box DCS reports for the type, which is authored by each module's designers and is far larger
  than a cargo bay for some types (41 m wide for the C-130J-30, the whole rotor disc for the
  Mi-8MT). A vehicle or crate parked beside such an aircraft can be marked as carried although
  DCS never loaded it; when the aircraft takes off, CTLD then reports a false release.
- The CH-47F is configured with whole-vehicle capability disabled although it can carry vehicles
  within its size and weight limits.
- Documentation states that the Il-76 has a native cargo bay and that native vehicles "reappear
  when they leave the bay". Neither is true.

## Solution

Native carry becomes a first-class, symmetric mode for crates and vehicles:

- Every player-controlled aircraft whose type declares a native cargo system is watched the same
  way, whatever its category. Whole vehicles are additionally admitted only when the type is also
  whole-vehicle capable, and only for the vehicle's own coalition.
- A native-carry vehicle is released back to the ground when DCS releases it, detected the same
  way native crates already are: by the vehicle drifting away from where it sat inside the
  aircraft. On the ground the release is reported as a native unload, in flight as a parachute
  release. A re-arm lock prevents the released vehicle from being loaded again while it is still
  inside the aircraft's box.
- A per-type, optional **aircraft hold box** (`aircraftHoldBox`) narrows the zone in which a vehicle
  or a crate counts as carried. When absent, the box reported by DCS is used, so types that need
  no adjustment keep following DCS. The defaults ship a hold box only for the C-130J-30 and the
  Mi-8MT, the two types whose DCS box is far larger than their cargo bay.
- If the carrying aircraft disappears without a death event (slot change, despawn), the vehicle is
  handled exactly as when the aircraft dies.
- The F10 unload and parachute entries for vehicles list virtual-carry vehicles only.
- The CH-47F default configuration allows whole-vehicle carry.
- Documentation, in English and French, explains the two modes with one rule: a cargo item is
  unloaded the way it was loaded.

## User Stories

1. As a C-130J-30 pilot, I want a vehicle that DCS unloads through the ramp to return to CTLD's
   ground state, so that I can load it again later or hand it to another CTLD action.
2. As a C-130J-30 pilot, I want a vehicle released in flight by the DCS parachute function to be
   reported as a parachute release, so that plugins and scoreboards can tell an airdrop from a
   ground unload.
3. As a pilot, I want a vehicle that left my aircraft to stop appearing in my F10 vehicle lists,
   so that I am never offered an action on cargo I no longer carry.
4. As a pilot, I want the F10 *Unload Vehicles* and *Parachute Vehicle* entries to show only the
   vehicles I loaded through the F10 menu, so that I cannot duplicate a vehicle that DCS still
   holds inside my aircraft.
5. As a pilot, I want a vehicle parked beside my aircraft not to be loaded while I taxi, so that
   only a vehicle actually driven into the aircraft counts.
6. As a BLUE pilot, I want to load only BLUE vehicles natively, so that an enemy vehicle can never
   be captured by driving under my wing.
7. As a CH-47F pilot, I want the Load / Extract Vehicles menu to appear, so that I can carry a
   light vehicle within my size and weight limits.
8. As a Mi-8MT pilot, I want my aircraft treated like any other native-carry aircraft for crates
   and vehicles, so that behavior does not depend on whether I fly a plane or a helicopter.
9. As a pilot who unloaded a vehicle by DCS while still inside the aircraft's box, I want CTLD not
   to reload it in a loop, so that the vehicle does not flip between states.
10. As a pilot whose aircraft was despawned or whose slot changed, I want the vehicle tracking to
    be cleaned up, so that no phantom loaded vehicle remains.
11. As a JTAC operator, I want a JTAC vehicle that DCS unloaded to resume lasing, so that a
    native unload does not silence the JTAC for the rest of the mission.
12. As a JTAC operator, I want a JTAC vehicle whose transport is gone to be deregistered cleanly,
    so that its laser code and claim are freed.
13. As a mission maker, I want AI transports never to load vehicles natively, so that the AI
    logistics keep working through the virtual path I configured.
14. As a mission maker, I want the Il-76 documented as AI-only with no native cargo, so that I do
    not configure it as if a pilot could fly it.
15. As a mission maker, I want the CH-47F default configuration to allow whole vehicles, so that I
    get the intended behavior without editing my mission configuration.
16. As a mission maker, I want one page explaining virtual carry, native carry and the "unload
    the way you loaded" rule, so that I can brief my players in one paragraph.
17. As a mission maker, I want a per-aircraft table of what each type can do natively, so that I
    know which aircraft support which carry mode.
18. As a plugin or scene author, I want `OnVehicleUnloaded` to be published for native releases
    with a reason that separates ground from air, so that my listener does not need to poll.
19. As a plugin author, I want `OnVehicleDead` published when a native-carry vehicle is lost with
    its aircraft, so that my accounting stays correct.
20. As a plugin author, I want `OnVehicleLoaded` and `OnVehicleUnloaded` to keep their existing
    payload shape, so that my existing listeners keep working.
21. As a developer, I want crates and vehicles to follow the same detection rules (ground, speed,
    drift, transport lost), so that I reason about native carry once.
22. As a developer, I want the native scan limited to player units, so that a busy mission does not
    pay for scanning every AI airplane each second.
23. As a developer, I want the published unload reason decoupled from the mechanism that recovers
    the unit, so that a parachute release of a native vehicle does not respawn a duplicate.
24. As a developer, I want the previously unused native tracking table to hold the drift
    reference, so that no dead state remains in the vehicle spawner.
25. As a developer, I want a read-only live check that reads the DCS box of every native-cargo
    aircraft type, so that a DCS update that changes a box is noticed.
26. As a maintainer, I want the misleading comments about the Il-76 and about "parachute" native
    exits corrected, so that the next reader is not misled.
27. As a maintainer, I want the roadmap entry closed and the two follow-up entries (native crate
    menus, manual weight limit) recorded, so that nothing found during the grill is lost.
28. As a French-speaking pilot, I want the same explanations in French, so that the guidance does
    not depend on reading English.
29. As a tester, I want a live C-130J-30 scenario that loads, unloads and airdrops a vehicle, so
    that drift, release position and unit lifetime are verified against real DCS behavior.
30. As a tester, I want a checklist for the Mi-8MT and C-130J-30 false-positive cases (a vehicle
    beside the aircraft), so that I can confirm the hold box excludes them.
31. As a C-130J-30 pilot, I want a vehicle parked under my wing not to be counted as carried, so
    that only a vehicle actually inside the cargo bay is loaded.
32. As a Mi-8MT pilot, I want a vehicle under my rotor disc not to be counted as carried, so that
    landing next to a vehicle never loads it.
33. As a mission maker, I want to override the hold box of any aircraft type in my configuration,
    so that a modded aircraft with an oversized DCS box can be made reliable without a code change.
34. As a mission maker, I want an aircraft type with no hold box to keep following the DCS box, so
    that I only configure the types that need it.
35. As a mission maker, I want an invalid hold box (inverted or malformed) rejected by validation,
    so that a typo cannot silently disable native loading.
36. As a developer, I want a consistency check that a configured hold box lies inside the DCS box
    of its type, so that a DCS update that shrinks a box is caught.
37. As a C-130J-30 or Mi-8MT pilot, I want a crate lying under my wing or rotor disc not to be
    counted as carried, so that only a crate DCS actually loaded is tracked as native carry.
38. As a developer, I want the vehicle scan and the crate scan to resolve the box of a type through
    one shared rule, so that the same aircraft never has two different "inside" zones.

## Implementation Decisions

- **Candidate transports.** The native scan considers player-controlled units only, any category
  (airplane or helicopter), whose type declares a native cargo system. AI units are never scanned.
  Whole-vehicle admission additionally requires the type's whole-vehicle capability. This aligns
  the vehicle scan with the crate scan, which already uses the player registry and the native
  cargo flag.
- **Entry (vehicles).** A `WAITING` vehicle is loaded as native carry only when all of the
  following hold: the transport is on the ground, its speed is at most 0.5 m/s (same guard as
  crates), the vehicle's point is inside the type's hold box (strict, no margin; see "Aircraft hold
  box" below), and the vehicle's coalition equals the transport's coalition. Type, weight and count are **not**
  re-checked by CTLD: DCS is the authority for what a native cargo system accepts. A vehicle that
  fails the coalition check stays `WAITING`, silently.
- **Drift reference.** At native load, the vehicle's offset in the transport's local frame is
  memorised in the spawner's native tracking table (currently written and never read).
- **Exit by drift.** Each tick, for every native-carry vehicle whose transport still exists, the
  local-frame offset is recomputed; a change of more than 1 m from the reference means DCS
  released the vehicle (same threshold and reasoning as native crates).
- **Unload reason versus mechanism.** The published reason is `dcs_native` when the transport is
  on the ground and `parachute` when it is airborne (decided with the project's shared in-air
  helper). The mechanism that recovers the live unit instead of respawning it depends on the
  vehicle having been **native-carried**, not on the published reason. Virtual-carry unloads are
  unchanged.
- **Re-arm lock.** Once a native-carry vehicle has been released, it cannot be natively loaded
  again until it has been observed outside its former transport's box enlarged by 0.5 m (a local
  constant, not exposed in configuration), or until that transport is gone. This makes a
  load/unload loop impossible by construction, not merely unlikely.
- **Transport lost without a death event.** The native tick detects that the recorded transport no
  longer exists and applies the same handling as the existing transport-death path: remove the
  vehicle from tracking, deregister a JTAC silently, publish `OnVehicleDead`. Detection by tick
  covers slot change and despawn, which raise no death event.
- **Menu filter.** The list feeding *Unload Vehicles* and *Parachute Vehicle* excludes
  native-carry vehicles. Weight accounting for virtual carry is unchanged.
- **Default configuration.** The CH-47F default gains whole-vehicle capability; its loadable-type
  lists, weight limit and vehicle count are already present. The generated defaults copy is
  refreshed by the normal build.
- **Aircraft hold box.** A new optional per-type capability, `aircraftHoldBox`, holds a box in the
  aircraft's local frame (x forward, y up, z right, metres; a minimum and a maximum corner). It is
  the zone in which a vehicle counts as carried. Resolution: when a type has a hold box, it is
  used; otherwise the DCS descriptor box is used. Both the entry test and the re-arm lock read the
  resolved box. The shipped defaults set a hold box only for the C-130J-30 and the Mi-8MT; their
  values are tuned visually against the aircraft (using the box-drawing diagnostic adapted to
  draw a candidate box) and confirmed by the user before merge. The key is read by **both** native
  scans, the vehicle scan and the crate load detection, through one shared resolution rule. One
  deliberate exception: the check that keeps a freshly spawned crate out of a neighbouring
  aircraft's volume keeps using the full DCS box, since its purpose is to avoid the whole
  envelope, wings included. Crate behavior therefore changes for types that ship a hold box
  (C-130J-30, Mi-8MT) and is unchanged elsewhere. Validation rejects a malformed box (missing corner or axis, minimum not below
  maximum). The configuration schema, its English and French descriptions, the mission-maker
  documentation and the `ctld-tools` editor (nested table versus six scalar fields — to be settled
  when the ticket starts, after checking what the editor supports) are all updated.
- **Descriptor box is the UserBox.** The box returned by the runtime type descriptor is the
  model's UserBox authored by each module's designers, verified against the DCS model viewer for
  the CH-47D, the Mi-8MT and the legacy C-130. It is neither the model's bounding box nor a
  tight cargo-bay volume, and it differs in convention per type. No code assumption about
  tightness is added.
- **Interfaces.** No new event, no new configuration key and no payload change. `OnVehicleUnloaded`
  gains a new possible `method` value (`parachute`) on the native path.
- **Documentation.** Pilot, mission-maker and developer pages (EN and FR) are corrected: the Il-76
  is AI-only, native carry vehicles are released by DCS and tracked by CTLD, the two carry modes
  and their rule, and a per-type capability table. Code comments that describe the Il-76 as native
  or promise a parachute exit through the old mechanism are corrected. The vehicle subsystem page
  is rewritten where it says the exit is a no-op.
- **Glossary.** `CONTEXT.md` gains **Virtual carry** and **Native carry** (already written).

## Testing Decisions

- A good test drives observable behavior only: state transitions, published events, what a menu
  lists, what a configuration contains. It does not assert on private tables or call order.
- **Seam 1 — one tick of the native scan with DCS doubles** (players, positions, speed, height):
  entry guards (ground, speed, coalition), exit by drift, published reason on ground and in
  flight, re-arm lock, transport lost. Prior art: the pure-math box helper specs; the native
  scan itself has no test today, so this seam is new but sits on the existing spawner API.
- **Seam 1b — the crate load detection tick with DCS doubles:** a crate inside the resolved box
  is detected as native carry, a crate inside the DCS box but outside the hold box is not; the
  existing crate behaviors (speed guard, conversion, drift release) are unchanged. Prior art: the
  crate manager specs.
- **Seam 2 — transport death and silent disappearance:** vehicle removed, JTAC deregistered,
  `OnVehicleDead` published, with and without a death event.
- **Seam 3 — menu-visible vehicle lists:** a native-carry vehicle never appears in the unload or
  parachute lists, a virtual-carry one always does.
- **Seam 4 — default configuration:** the CH-47F is whole-vehicle capable; native candidates are
  player units of native types across categories, with the whole-vehicle condition for vehicles;
  the hold box precedence (configured box wins, absent key falls back to the DCS box); the
  validation of a malformed hold box; the shipped defaults carry a hold box for exactly the
  C-130J-30 and the Mi-8MT. Prior art: the aircraft capabilities spec and the configuration specs.
- **Seam 5 — live DCS scenario with the C-130J-30** (`auto-check` tier): real drift on release,
  where DCS places the released vehicle, whether the unit stays alive, in-flight release.
- **Seam 6 — manual in-game checklist** for the Mi-8MT and C-130J-30: a vehicle or a crate parked
  under the wing or rotor disc must not be loaded; a vehicle driven into the cargo bay, and a
  crate loaded through the DCS cargo UI, must be. Also used to tune and confirm the shipped hold
  box values.
- **Box consistency check** (live, read-only): reads the descriptor box of every native-cargo type
  in the configuration without spawning, and fails when a configured hold box is not contained
  in it.
- Seams 1-4 run in CI (busted). Seams 5-6 need a live mission and the user's explicit approval
  before the PR, per the project workflow.

## Out of Scope

- **Native crate menus.** *Drop Crate(s)* and *Parachute Crates* also list native-carry crates
  (the "loaded by CTLD" predicate is true for any loaded crate), against the comments and the
  parachute page. Separate crate lot, recorded in the roadmap.
- **Manual vehicle weight limit.** The per-type maximum vehicle weight is enforced only for the AI;
  the manual F10 load does not check it. Recorded in the roadmap.
- **Config key `76MD`.** The stock in-game Il-76 type is `IL-76MD`, while the configuration key is
  `76MD` (a mod name in the legacy). Whether the entry matches anything is not investigated here.
- **The `Hercules` mod.** It has no native cargo (confirmed by the user) and stays virtual.
- **Troops and slingload.** No native path exists for them; unchanged.
- **A shared implementation between crates and vehicles.** Only the rules are aligned and
  documented; no common abstraction is introduced.
- **A distinct in-flight state for a released vehicle.** After a native release the vehicle
  returns to `WAITING` immediately, in flight or not; a dedicated "falling" state is not added.

## Further Notes

- **Descriptor boxes measured live (metres, length × height × width):** C-130J-30
  35.13 × 12.12 × 41.03; legacy C-130 29.71 × 13.54 × 41.34; IL-76MD 47.03 × 14.79 × 51.99;
  Mi-8MT 25.26 × 7.51 × 22.16 (includes the rotor disc); CH-47Fbl1 15.82 × 5.88 × 4.38;
  CH-47D 15.12 × 4.74 × 3.76; UH-1H 12.81 × 3.22 × 3.14; Mi-24P 19.07 × 4.26 × 3.14. Hercules,
  76MD, UH-60L and SK-60 are unknown to the test installation. A diagnostic script that draws
  these boxes on the F10 map and with corner flares was added during the grill.
- **Decision (settled 2026-09-29):** the DCS box of the C-130J-30 (41 m wide) and of the Mi-8MT
  (rotor disc) is much larger than a cargo bay. Rather than accept it or wait for a live test to
  decide, a per-type optional `aircraftHoldBox` replaces it for vehicle admission (proposed by the
  user, named by the user). Types without one follow DCS.
- **Unverified in game:** that a vehicle in native carry stays alive and physically linked; where
  DCS places a released vehicle; that helicopters with native cargo physically accept a whole
  vehicle. The design tolerates each of them being false (the drift reference and the re-arm
  lock do not depend on where the vehicle lands).
- The DCS bridge MCP server was unavailable during the grill; live measurements went through the
  runner's HTTP endpoint.

## Definition of Done

- Seams 1, 1b and 2-4 covered by busted specs, all green; coverage floor not lowered.
- Native crate load detection re-tested live on the C-130J-30 and the Mi-8MT (a crate load through
  the DCS cargo UI still works; a crate under the wing or rotor disc is ignored).
- `luacheck` clean; the inline suppression on the empty exit branch removed with the branch itself.
- `CHANGELOG.md` `[Unreleased]` updated (the lot changes `src/`).
- Docs corrected in EN and FR; i18n dictionaries regenerated by the build; pre-push hook green.
- Live scenario (seam 5) run against a live mission and passing; checklist (seam 6) completed by
  the user, with its outcome recorded in this PRD.
- Shipped hold box values for the C-130J-30 and the Mi-8MT tuned visually and confirmed by the
  user; schema, EN/FR descriptions, mission-maker docs and the `ctld-tools` editor updated for
  `aircraftHoldBox`.
- Roadmap: the native bbox-exit entry closed; two follow-up entries added.
- Index line in `.backlog/README.md` set to `merged (PR #NN)` in the delivering PR.
