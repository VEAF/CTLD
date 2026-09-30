# FIX-NATIVE-CARRY-DETECTION — make native carry loads and unloads fully tracked by CTLD

**Status:** ⬜ ready.

Formalizes the `dev/roadmap.md` entry "Native-cargo bbox-exit detection is unimplemented" plus
`grill-with-docs` sessions (2026-09-29, revised 2026-10-01) that widened it: the gap found in the
vehicle spawner is one symptom of a broader inconsistency between **virtual carry** and **native
carry** (see the glossary in `CONTEXT.md`). The decisions below are settled unless a line says
"provisional". The first design (2026-09-29) detected native carry geometrically, with a per-type
hold box; the 2026-10-01 session replaced it with the DCS on-board cargo list after live
measurements (see **ADR 0022**).

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
- CTLD guesses what is inside a native-carry aircraft from positions: a vehicle or crate is "inside"
  when its point falls in the box DCS reports for the type. That box is authored by each module's
  designers and is far larger than a cargo bay for some types (41 m wide for the C-130J-30, the
  whole rotor disc for the Mi-8MT). The vehicle test also has no ground, speed or coalition guard: a
  taxiing aircraft can "swallow" a parked vehicle, and a BLUE aircraft can load a RED vehicle. When
  the aircraft takes off, CTLD then reports a false release.
- The native scan walks every airplane group, AI included, and only airplanes. The AI-only Il-76
  can therefore load a parked vehicle "natively", colliding with the virtual logic the AI
  transport already uses. Helicopters with native cargo are never scanned for vehicles.
- The CH-47F is configured with whole-vehicle capability disabled although it can carry vehicles
  within its size and weight limits.
- Documentation states that the Il-76 has a native cargo bay and that native vehicles "reappear
  when they leave the bay". Neither is true.

## Solution

Native carry becomes a first-class, symmetric mode for crates and vehicles, read from what DCS
itself reports:

- Every player-controlled aircraft whose type declares a native cargo system is watched the same
  way, whatever its category. CTLD reads the aircraft's **on-board cargo list**: a tracked item is in
  native carry exactly while it is on the list. No position test decides what is on board.
- A native-carry item leaves the list the moment DCS releases it. On the ground the release is
  reported as a native unload and the item returns to its ground state. In flight it is reported as a
  parachute release and the item stays in a falling state until it has landed, then returns to its
  ground state. The same rules apply to crates and to vehicles.
- A released native-carry vehicle is **not** respawned: its DCS unit stayed alive all along and CTLD
  recovers it. A vehicle parachuted with CTLD's own (virtual) parachute is respawned at its landing
  position, as today.
- If the carrying aircraft disappears without a death event (slot change, despawn), the vehicle is
  handled exactly as when the aircraft dies.
- The F10 unload and parachute entries for vehicles list virtual-carry vehicles only.
- The CH-47F default configuration allows whole-vehicle carry.
- Documentation, in English and French, explains the two modes with one rule: a cargo item is
  unloaded the way it was loaded.

## User Stories

1. As a C-130J-30 pilot, I want a vehicle that DCS unloads through the ramp to return to CTLD's
   ground state, so that I can load it again later or hand it to another CTLD action.
2. As a C-130J-30 pilot, I want a vehicle or crate released in flight by the DCS parachute function
   to be reported as a parachute release, so that plugins and scoreboards can tell an airdrop from a
   ground unload.
3. As a pilot, I want a vehicle that left my aircraft to stop appearing in my F10 vehicle lists,
   so that I am never offered an action on cargo I no longer carry.
4. As a pilot, I want the F10 *Unload Vehicles* and *Parachute Vehicle* entries to show only the
   vehicles I loaded through the F10 menu, so that I cannot duplicate a vehicle that DCS still
   holds inside my aircraft.
5. As a pilot, I want a vehicle or a crate parked beside or under my aircraft (wing, rotor disc) never
   to be counted as carried, so that only what DCS actually loaded is tracked.
6. As a pilot, I want a crate loaded and released through the DCS cargo UI to be handled by the same
   rules as a vehicle, so that native carry behaves the same for both.
7. As a CH-47F pilot, I want the Load / Extract Vehicles menu to appear, so that I can carry a
   light vehicle within my size and weight limits.
8. As a Mi-8MT pilot, I want my aircraft treated like any other native-carry aircraft for crates
   and vehicles, so that behavior does not depend on whether I fly a plane or a helicopter.
9. As a pilot who unloaded a vehicle through DCS, I want CTLD not to reload it by itself, so that
   the vehicle does not flip between states: it is loaded again only when DCS loads it again.
10. As a pilot whose aircraft was despawned or whose slot changed, I want the vehicle tracking to
    be cleaned up, so that no phantom loaded vehicle remains.
11. As a JTAC operator, I want a JTAC vehicle that DCS unloaded to resume lasing once it is on the
    ground, so that a native unload does not silence the JTAC for the rest of the mission.
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
20. As a plugin author, I want `OnVehicleLoaded`, `OnVehicleUnloaded`, `OnCrateLoaded` and
    `OnCrateUnloaded` to keep their existing payload shape, so that my existing listeners keep
    working.
21. As a developer, I want crates and vehicles to follow the same detection rules (on-board list,
    ground or air release, transport lost), so that I reason about native carry once.
22. As a developer, I want the native scan limited to player units, so that a busy mission does not
    pay for scanning every AI airplane each second.
23. As a developer, I want the published unload reason decoupled from the mechanism that recovers
    the unit, so that a native parachute release never respawns a duplicate while a CTLD
    (virtual) parachute still respawns the vehicle at its landing position.
24. As a developer, I want a vehicle released natively in flight to have a falling state until it
    lands, like a crate, so that it is not offered for loading while still in the air and its JTAC
    resumes only on the ground.
25. As a maintainer, I want one warning per aircraft type when its on-board cargo list cannot be
    read, so that an unsupported type is noticed without flooding the log.
26. As a maintainer, I want items on the list that CTLD does not track (tablet-spawned cargo, editor
    crates of an unknown type) ignored with a debug trace, so that they are diagnosable but never
    change CTLD state.
27. As a developer, I want a native load converted to a CTLD load (for types that ask for it) to be
    processed once, so that the conversion delay never makes CTLD handle the same item twice.
28. As a maintainer, I want the misleading comments about the Il-76 and about "parachute" native
    exits corrected, so that the next reader is not misled.
29. As a maintainer, I want the roadmap entry closed and the follow-up entries recorded, so that
    nothing found during the grill is lost.
30. As a French-speaking pilot, I want the same explanations in French, so that the guidance does
    not depend on reading English.
31. As a tester, I want a live C-130J-30 scenario that loads, unloads and airdrops a vehicle and a
    crate, so that list behavior, release position, unit lifetime and landing are verified.
32. As a tester, I want a checklist per native-cargo type (C-130J-30, CH-47F, Mi-8MT, UH-1H, Mi-24P)
    confirming the on-board list works and that nothing parked beside the aircraft is counted.

## Implementation Decisions

- **Source of truth.** For each watched aircraft, CTLD reads its on-board cargo list each tick. A
  tracked item is native-carried exactly while it is on that list (**ADR 0022**). There is no
  aircraft hold box, no ground, speed or coalition entry guard, no drift reference and no re-arm
  lock: DCS is the authority for what it loaded and when it released it.
- **Candidate transports.** The native scan considers player-controlled units only, any category
  (airplane or helicopter), whose type declares a native cargo system. AI units are never scanned.
  Whole-vehicle tracking additionally requires the type's whole-vehicle capability. Type, weight
  and count are not re-checked by CTLD.
- **Item identity.** A crate on the list is matched by its object name to a tracked crate. A whole
  vehicle appears through a companion list entry named `CRG:` followed by its unit name; CTLD
  strips the prefix to find the tracked vehicle. Only tracked items are acted on. Other entries are
  ignored with a debug-level trace; they are never adopted (see Out of Scope).
- **Entry.** A tracked `WAITING` vehicle (or a tracked crate on the ground) that appears on the
  list becomes native carry: `OnVehicleLoaded` / `OnCrateLoaded` with method `dcs_native`, payloads
  unchanged. A JTAC vehicle stays suspended while carried.
- **Exit.** A native-carry item that disappears from the list is released. Published reason:
  `dcs_native` when the transport is on the ground, `parachute` when it is airborne (decided with
  the project's shared in-air helper). On the ground the item returns to its ground state
  (`LANDED` for a crate, `WAITING` for a vehicle) immediately. In flight it goes to a falling state
  and returns to its ground state once it has landed, using the landing criterion crates already
  use, now shared by vehicles. A JTAC vehicle resumes lasing when it is back on the ground.
- **New vehicle state.** The vehicle state set gains a falling state, used only for a native
  in-flight release. Edge cases covered by specs: destroyed while falling, lost in water, transport
  gone while it falls.
- **Unload reason versus mechanism.** The published reason is independent of the mechanism that
  handles the live unit. A native-carried vehicle is never respawned: its live unit is recovered
  (measured: a vehicle released by the DCS parachute stayed alive all the way down). A vehicle
  parachuted with CTLD's own virtual parachute is respawned at its landing position, unchanged.
  Virtual-carry unloads (menu, AI dropoff) are unchanged.
- **Transport lost without a death event.** The native tick detects that the recorded transport no
  longer exists and applies the same handling as the existing transport-death path: remove the
  vehicle from tracking, deregister a JTAC silently, publish `OnVehicleDead`. Idempotent against a
  death event.
- **Conversion of native crate loads.** The per-type `convertNativeLoadToCTLD` option is kept
  (enabled by default on the UH-1H and CH-47Fbl1). Its trigger becomes the crate appearing on the
  list; the conversion itself (release the DCS load, then a CTLD load after a short delay) is
  unchanged, and a "conversion in progress" mark prevents the same crate from being handled twice
  during that delay. It stays crate-only.
- **Unreadable list.** If reading the list fails for a type (error or function missing), CTLD
  logs one warning for that type and does not watch it. There is no geometric fallback.
- **Crate code replaced.** The crate manager's bounding-box entry test, its speed guard, its
  local-frame drift reference and the native link table are replaced by the list rules above. The
  check that keeps a freshly spawned crate out of a neighbouring aircraft's volume is unrelated to
  detection and is left as it is.
- **Menu filter.** The list feeding *Unload Vehicles* and *Parachute Vehicle* excludes
  native-carry vehicles. Weight accounting for virtual carry is unchanged.
- **Default configuration.** The CH-47F default gains whole-vehicle capability; its loadable-type
  lists, weight limit and vehicle count are already present. The generated defaults copy is
  refreshed by the normal build.
- **Interfaces.** No new event, no new configuration key and no payload change. `OnVehicleUnloaded`
  gains a possible `method` value (`parachute`) on the native path.
- **Documentation.** Pilot, mission-maker and developer pages (EN and FR) are corrected: the Il-76
  is AI-only, native-carry vehicles and crates are released by DCS and tracked by CTLD, the two
  carry modes and their rule, and a per-type capability table. Code comments that describe the
  Il-76 as native or promise a parachute exit through the old mechanism are corrected. The vehicle
  subsystem page is rewritten where it says the exit is a no-op.
- **Glossary.** `CONTEXT.md` has **Virtual carry**, **Native carry** and **On-board cargo list**
  (already written).

## Testing Decisions

- A good test drives observable behavior only: state transitions, published events, what a menu
  lists, what a configuration contains. It does not assert on private tables or call order.
- **Seam 1 — one tick of the native scan with DCS doubles** (players, an on-board list, positions,
  height): a tracked vehicle entering the list, leaving it on the ground, leaving it in flight,
  landing afterward, a JTAC resuming only on the ground, the `CRG:` name mapping, an untracked entry
  ignored, an unreadable list warning once per type, a listing never acted on for an AI unit. Prior
  art: the vehicle spawner specs; the native scan itself has no test today.
- **Seam 1b — the crate detection tick with DCS doubles:** a crate entering and leaving the list,
  ground and air release, conversion for a converting type processed once. The existing crate
  behaviors unrelated to detection stay green.
- **Seam 2 — transport death and silent disappearance:** vehicle removed, JTAC deregistered,
  `OnVehicleDead` published, with and without a death event, including while falling.
- **Seam 3 — menu-visible vehicle lists:** a native-carry vehicle never appears in the unload or
  parachute lists, a virtual-carry one always does.
- **Seam 4 — default configuration:** the CH-47F is whole-vehicle capable; native candidates are
  player units of native types across categories, with the whole-vehicle condition for vehicles.
  Prior art: the aircraft capabilities spec and the configuration specs.
- **Seam 5 — live DCS scenario with the C-130J-30** (`auto-check` tier): load and release a vehicle
  and a crate on the ground, release in flight, the vehicle landing alive.
- **Seam 6 — manual in-game checklist per native-cargo type** (C-130J-30, CH-47F, Mi-8MT, UH-1H,
  Mi-24P): the on-board list exists and reports a crate and a vehicle; something parked beside the
  aircraft is never counted; several items aboard; native unload.
- Seams 1-4 run in CI (busted). Seams 5-6 need a live mission and the user's explicit approval
  before the PR, per the project workflow.

## Out of Scope

- **Native crate menus.** *Drop Crate(s)* and *Parachute Crates* also list native-carry crates
  (the "loaded by CTLD" predicate is true for any loaded crate), against the comments and the
  parachute page. Separate crate lot, recorded in the roadmap.
- **Manual vehicle weight limit.** The per-type maximum vehicle weight is enforced only for the AI;
  the manual F10 load does not check it. Recorded in the roadmap.
- **Adopting cargo CTLD does not track.** Cargo created with the C-130J-30 loadmaster tablet (CDS
  crates, barrels, containers) and editor crates of an unknown type are ignored. Adopting them as
  generic CTLD crates is a separate feature, recorded in the roadmap.
- **Converting a native vehicle to a CTLD vehicle.** `convertNativeLoadToCTLD` stays crate-only;
  extending it to vehicles is a separate feature, recorded in the roadmap.
- **Config key `76MD`.** The stock in-game Il-76 type is `IL-76MD`, while the configuration key is
  `76MD` (a mod name in the legacy). Whether the entry matches anything is not investigated here.
- **The `Hercules` mod.** It has no native cargo (confirmed by the user) and stays virtual.
- **Troops and slingload.** No native path exists for them; unchanged.
- **A shared implementation between crates and vehicles.** Only the rules are aligned and
  documented; no common abstraction is introduced beyond reading the list.

## Further Notes

- **Live measurements, 2026-09-30 (C-130J-30, unit `c130-1`, loadmaster tablet):**
  - The on-board list returned one entry for a natively loaded crate (`cr1-1`, type `ammo_cargo`,
    1500 kg): name, type name, display name, weight, category 6, coalition, position. DCS moved the
    crate from 33.6 m away into the hold, at local (fwd 8.975, up -3.220, right -0.948).
  - A natively loaded Hummer stayed a **live unit** (alive, life intact), teleported into the hold
    at local (7.299, -3.220, 0.000); the list held a companion entry `CRG:Sol_g-7-1`, type
    `pallete`, weight 3990, same position. Loading is not animated: the item appears in the hold
    with no intermediate movement.
  - A vehicle released in flight by the native parachute left the list at release (about 1449 m
    above ground), kept existing, alive, and descended at about 9 m/s to a landing with no
    damage; it moved thousands of metres from the aircraft while the aircraft flew on.
  - After a native unload, the crate was back on the ground and off the list. One extra object
    (`cr1-1-1`) appeared and was not explained.
  - An editor crate of type `ammo_cargo` is ignored by CTLD at start ("unknown cargo type"), yet
    DCS lists it when loaded: hence the rule of ignoring untracked entries.
- **Discarded geometric design, kept for history.** Descriptor boxes measured (length × height ×
  width, metres): C-130J-30 35.13 × 12.12 × 41.03; legacy C-130 29.71 × 13.54 × 41.34; IL-76MD
  47.03 × 14.79 × 51.99; Mi-8MT 25.26 × 7.51 × 22.16; CH-47Fbl1 15.82 × 5.88 × 4.38; CH-47D
  15.12 × 4.74 × 3.76; UH-1H 12.81 × 3.22 × 3.14; Mi-24P 19.07 × 4.26 × 3.14. The descriptor box is
  the model's UserBox, verified against the DCS model viewer. A working C-130J-30 cargo volume had
  been derived from the EDM model (floor 17.4 m long at local height -3.23, walls about ±2.1 m) and
  matched the live positions; it is no longer used.
- **Unverified in game:** the on-board list on the CH-47F, Mi-8MT, UH-1H and Mi-24P; several items
  aboard at once; a crate released in flight; whether a whole vehicle is accepted by helicopters
  with native cargo. All are covered by the live-validation ticket. The design tolerates a type
  failing: it is then handled as a special case (for example by disabling its native flag).
- Existing diagnostics that read the list: `tests/dcs/dev/diag/diag_cargos_*.lua`,
  `tests/dcs/util/dump_cargos.lua`.
- The DCS bridge MCP server was unavailable during the grill; live measurements went through the
  runner's HTTP endpoint.

## Definition of Done

- Seams 1, 1b and 2-4 covered by busted specs, all green; coverage floor not lowered.
- Native crate and vehicle detection re-tested live on the C-130J-30; the on-board list verified
  (or the type handled as a special case) on every native-cargo type.
- `luacheck` clean; the inline suppression on the empty exit branch removed with the branch itself.
- `CHANGELOG.md` `[Unreleased]` updated (the lot changes `src/`).
- Docs corrected in EN and FR; i18n dictionaries regenerated by the build; pre-push hook green.
- Live scenario (seam 5) run against a live mission and passing; checklist (seam 6) completed by
  the user, with its outcome recorded in this PRD.
- Roadmap: the native bbox-exit entry closed; the follow-up entries added.
- Index line in `.backlog/README.md` set to `merged (PR #NN)` in the delivering PR.
