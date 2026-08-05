Status: ⬜ ready

# PRD — FIX-PARACHUTE-GROUP-NAME-COLLISION : parachuted groups collide on template name

## Problem Statement

A helicopter pilot loads several troop groups from a troop zone — including two groups
of the same type (e.g. two "Standard Infantry" squads) plus a different-type group
(e.g. one "Mortar" squad) — and parachutes them in flight, one after another. The first
group lands and spawns correctly. The moment the second group of the **same** type
lands, it spawns correctly too, but **the first group vanishes** — as if it had never
existed. Parachuting the third group (a different type) works fine and does not affect
the surviving second group. Reported by a tester (2026-08-05) and reproduced multiple
times with identical results.

## Solution

Every parachuted troop group and its units get a unique DCS object name, so that two
groups loaded from the same template no longer collide on identical names when spawned.
The pilot sees no change in behaviour or messaging — the fix is entirely internal to
how CTLD names the DCS objects it creates.

## User Stories

1. As a helicopter pilot, I want to load two troop groups of the same type and
   parachute them both, so that both survive as independent squads on the ground.
2. As a helicopter pilot, I want to load three or more troop groups of the same type
   and parachute them all in sequence, so that every one of them survives, not just
   the last.
3. As a helicopter pilot, I want to parachute a mix of same-type and different-type
   troop groups in any order, so that the drop order never determines which groups
   survive.
4. As a helicopter pilot, I want the "Parachuting %1 (%2 troops) — landing in ~%3s"
   message to keep showing the plain template name (e.g. "Standard Infantry"), so that
   the change in internal naming is invisible to me.
5. As a helicopter pilot carrying a JTAC-capable troop group, I want the JTAC unit to
   still start lasing correctly after parachuting, so that laser designation keeps
   working regardless of the internal renaming.
6. As a mission maker relying on `nbLimitSpawnedTroops` (the coalition troop cap), I
   want every parachuted group to still be counted toward the cap, so that the limit
   remains accurate after the fix.
7. As a helicopter pilot who lands near a previously-parachuted group, I want to be
   able to field-load it back onto my transport with its original template info intact
   (weight, troop count, specific params), so that picking up a dropped group still
   works after the fix changes its DCS name.
8. As a mission maker, I want groups that die in combat after being parachuted to still
   be cleaned up from CTLD's internal tracking (`_droppedGroups` / `_droppedTemplates`),
   so that stale entries don't accumulate under the new naming scheme.
9. As a helicopter pilot parachuting a single troop group (no other group of the same
   type in play), I want behaviour identical to today, so that the fix introduces no
   regression for the common case.
10. As a developer reading a mission's unit list in the DCS Mission Editor / logs after
    a parachute drop, I want spawned group and unit names to look like standard DCS
    naming (`GroupName-N`), so that debugging a live mission is no harder than for any
    other spawned group.

## Implementation Decisions

- **Unique group naming**: the DCS group name for a parachuted troop group is no longer
  the raw config template display name. It is suffixed with the project's existing
  unique-id generator (the same one `CTLDObjectRegistry.spawnObject` already uses for
  every other spawn path — fast-rope / ground drop, crates, vehicles, JTAC drones — so
  this fix brings `parachuteTroops` in line with the established convention rather than
  introducing a new one).
- **Per-unit naming**: unit names within a parachuted group are derived from the
  group's own resolved unique name plus a 1-based index (`<groupName>-<unitIndex>`),
  mirroring standard DCS Mission Editor unit naming. A single unique-id allocation is
  made per group (not one per unit) — the group name already guarantees uniqueness, so
  units only need a per-group sequential index on top of it.
- **Downstream bookkeeping keyed by the resolved name, not the template name**: the
  coalition's live-group list and the per-group template-info map (used to restore
  weight/troop-count/specific-params when a dropped group is later field-loaded back
  onto a transport) must be keyed off the group's actual resolved DCS name — matching
  how every other troop-drop path in the file already keys them. `parachuteTroops` is
  currently the sole path that keys them by the raw (colliding) template name instead;
  this fix removes that inconsistency.
- **JTAC lasing unaffected by construction**: JTAC unit resolution after a parachute
  spawn is positional (by index within the spawned group), not name-based, and the
  slot bookkeeping built at troop embarkation is independent of the spawn-time unit
  names. No change is needed there — confirmed during design, called out here so the
  fix isn't mistaken for touching it.
- **Player-facing messages unaffected**: every player-visible string (drop announcement,
  landing confirmation, etc.) keeps using the plain template display name. Only the
  internal DCS object identifiers change.
- **No ADR**: the naming scheme is an internal convention, cheap to reverse, with no
  external contract — doesn't meet the bar for an ADR.
- **No `CONTEXT.md` change**: this is an implementation detail (object naming), not a
  domain-glossary term.

## Testing Decisions

Good tests here assert externally observable outcomes — distinct DCS object names and
group survival — not the literal naming string format, which is an implementation
detail that could change without breaking the guarantee that matters.

- **Seam**: functional-level test against `CTLDTroopManager:parachuteTroops`, the
  existing seam already exercised by the `F-059/F-060 — parachuteTroops` describe block
  in `tests/ci/functional/parachute_spec.lua`. No new seam is introduced.
- **Timer stub caveat**: the actual DCS spawn happens inside the `timer.scheduleFunction`
  callback in `parachuteTroops`, and the project-wide default stub for
  `timer.scheduleFunction` (`tests/ci/helpers/dcs_stubs.lua`) is a no-op that never runs
  it — which is why the existing F-059/F-060 tests only assert on the *immediate*
  effects (event firing, `_inTransit` mutation). The new test(s) must locally override
  `timer.scheduleFunction` to run the callback synchronously, and stub `coalition.addGroup`
  / `Group.getByName` to capture spawned names and simulate live groups — the same
  pattern already used in `tests/ci/unit/object_registry_spec.lua` (`coalition.addGroup`
  stub) and `tests/ci/unit/deploy_managers_spec.lua` (synchronous `timer.scheduleFunction`
  override). Neither pattern is new to the codebase.
- **Coverage**:
  - Two groups loaded from the same template, parachuted in sequence: both spawn calls
    receive distinct names, and the first group is not destroyed/replaced when the
    second lands (i.e. still resolvable via `Group.getByName` / still present in
    `_droppedGroups` after the second drop).
  - Two same-template groups + one different-template group, parachuted in sequence:
    all three survive.
  - Single-group parachute (no collision possible): behaviour unchanged from today.
  - `_droppedTemplates` is keyed by the group's actual resolved name after the spawn,
    not by the raw template name — verified by fetching it via that resolved name.

## Out of Scope

- `disembark()` (fast-rope / ground drop) — already unaffected, already uses
  `CTLDObjectRegistry.spawnObject`'s unique naming, untouched by this fix.
- The parachute visual effect and descent-time mechanics.
- Any change to player-facing message wording.
- Vehicle / crate parachute paths (`parachuteVehicle`, `parachuteCrates`) — not
  reported as affected; out of scope unless a follow-up report surfaces the same class
  of bug there.

## Further Notes

Diagnosed and confirmed against the live code by the assistant in a prior session
(2026-08-05), including verifying that `ctld.utils.spawnAs` is a thin, guard-less
`pcall(coalition.addGroup, ...)` wrapper — consistent with DCS's known behaviour of
replacing an existing group when `coalition.addGroup` is called with an already-used
name, which is the actual mechanism behind the reported disappearance. Not a legacy-
parity issue: the virtual parachute feature has no equivalent in
`migration/source/CTLD.lua`.
