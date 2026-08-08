Status: ready

# FIX-FIELD-EXTRACT-CASUALTIES — field extraction ignores combat losses

## Problem Statement

A transport pilot who deploys a troop group, watches part of it die in combat, then lands nearby
to extract the survivors gets back the **original** headcount, not the survivor count. Ten
infantry dropped, three killed, seven left alive on the ground — re-embarking that group puts ten
troops back on the aircraft's manifest.

This silently breaks capacity accounting (a "full" load may in fact be smaller than reported) and
misleads the pilot about what they actually recovered. It is also an undeclared deviation from the
legacy `CTLD.lua`, which has always counted the DCS group's live units at the moment of extraction.

Separately, the "Extract from field" menu only ever showed distance to a nearby group, never its
size — so a pilot choosing between several dropped groups within extraction range has no way to
tell, before committing, which one will actually fit their remaining capacity.

## Solution

Field extraction (`embarkFromField`) now counts the group's **currently alive** DCS units at the
moment of extraction — mirroring the legacy behavior — instead of the headcount frozen at deploy
time. Cosmetic mortar-servant units (`SVNT_*`) stay excluded from that count, exactly as they are
today; only real troop-role units (including the mortar unit itself) are counted.

The "Extract from field" F10 menu (both the single-group direct button and the multi-group
submenu) now shows each group's current troop count alongside its name (and distance, in the
submenu case), so the pilot can choose with full information.

A group that has lost every real troop-role unit but still has a lone mortar servant standing
(mortar operator dead, servant alive) is no longer offered for extraction — there is nothing
useful to recover — and that residual servant is despawned automatically the instant this
degenerate state is reached, instead of lingering on the battlefield indefinitely.

## User Stories

1. As a transport pilot, I want the number of troops I recover when extracting a group from the
   field to reflect the survivors only, so that my aircraft's manifest is accurate.
2. As a transport pilot, I want the cargo weight of a re-extracted group to scale with the actual
   number of survivors, so that my weight/capacity accounting stays correct after casualties.
3. As a transport pilot with several dropped groups within extraction range, I want to see each
   group's current troop count in the "Extract from field" submenu, so that I can choose the group
   that best fits my remaining capacity before committing.
4. As a transport pilot with exactly one dropped group nearby, I want the direct "Extract: ..."
   button to also show that group's current troop count, so that the single-group case gives me
   the same information as the multi-group case.
5. As a transport pilot, I want a group reduced to zero real troops (only a leftover mortar
   servant) to no longer appear as extractable, so that I am not offered a pointless pickup.
6. As a mission maker, I want an orphaned mortar servant (its mortar operator killed, servant
   alive) to be cleaned up automatically, so that dead weight does not linger on the map for the
   rest of the mission.
7. As a transport pilot, I want the mortar unit itself to always count as a real troop (only its
   cosmetic servant excluded), so that a surviving mortar team is not undercounted.
8. As a transport pilot extracting a group that includes a JTAC, I want the troop count to include
   the JTAC unchanged from today, so that this fix introduces no regression on JTAC-carrying
   groups.
9. As a transport pilot loading fresh troops from a TRZ_ pickup zone, I want that count to remain
   exactly as accurate as it is today, so that this fix — scoped to field extraction — introduces
   no regression on the pickup-zone path.
10. As a transport pilot who extracts a group that took zero casualties, I want to recover the
    exact number originally deployed, so that the common, undamaged case is unaffected.
11. As a transport pilot who returns a casualty-reduced group to a TRZ_ pickup zone afterward, I
    want the zone's stock to be restored by the number of survivors I actually returned, not the
    original deployed count, so that zone stock accounting stays consistent with what changed
    hands.
12. As a transport pilot carrying several groups at once, I want "Check Cargo" to show the correct
    survivor-based count and weight for a group I re-extracted after losses, so that my full
    manifest stays accurate.
13. As a developer reading `CONTEXT.md`, I want "logical troop count" defined precisely and
    distinguished from the raw DCS unit count, so that the servant-exclusion rule is documented in
    one place instead of only living in code comments.
14. As a QA reviewer checking legacy parity, I want `src/`'s field-extraction count to match
    `migration/source/CTLD.lua`'s live-unit-count behavior, so that this documented deviation is
    closed.
15. As a translator maintaining the i18n dictionaries, I want the new/changed menu-label strings
    picked up by the existing dict-sync tooling, so that I don't have to hand-add keys.

## Implementation Decisions

- **Shared logical-count helper**: factor the existing servant-exclusion rule (already implemented
  in `CTLDTroopGroup:_syncFromDCSGroup` — count a live DCS group's units, excluding any named with
  the `SVNT` prefix) into a helper usable against any live `Group` object. Three call sites need
  it: the extraction count itself, the two extraction-menu labels, and the orphan-servant check in
  `onUnitDead`. No new naming convention introduced — reuses the `SVNT` prefix rule as-is.

- **`embarkFromField`**: replace the current `logicalCount = stored.total or groupSize` (which
  prefers the count frozen at deploy time) with the live count from the helper, applied to
  `nearest.group`. `stored.total` / `stored.weight` remain in `_droppedTemplates` but are now used
  **only** to derive the original per-unit average weight (`stored.weight / stored.total`), which
  still multiplies against the new, correct `logicalCount` to get proportional cargo weight — this
  part of the formula is unchanged.

- **Nearby-group lookups filter out zero-logical-count groups**: both the single-nearest lookup and
  the multi-group nearby lookup exclude any dropped group whose live logical count is 0, so a
  servant-only residue is never offered as an extraction target.

- **Menu labels** (embark/extract submenu, built in `refreshMenuSection`):
  - Single nearby group → `"Extract: %1 (%2 troops)"` (group name, logical count).
  - Multiple nearby groups (submenu entries) → `"%1 (%2 troops, %3m)"` (group name, logical count,
    distance in meters, floored as today).
  - Both go through `ctld.tr(...)`, consistent with every other player-facing string in this file.

- **`onUnitDead` reactive cleanup**: after removing the dead unit from a *deployed* (dropped, not
  in-transit) group's live view, if the group's logical count is now 0 while the DCS group still
  has units (i.e. only servants remain), destroy the residual DCS group immediately and purge it
  from `_droppedGroups[coalition]` and `_droppedTemplates[groupName]` — the same purge already
  performed by `_removeFromDropped`. No change to the JTAC-deregistration behavior already present
  in `onUnitDead`.

- **No config toggle.** This is a correctness fix (both the count and the servant cleanup), not a
  new mission-maker-configurable behavior.

- **No schema/state-machine change.** `CTLDTroopGroup.STATE` values and the troop state machine are
  untouched; this only changes how `unitTotal` is computed at the `FIELD_LOADED` transition and
  adds a reactive side effect in `onUnitDead`.

- **`CONTEXT.md`**: "Logical troop count" glossary entry already added under Gameplay domain,
  distinguishing it from the raw DCS unit count.

## Testing Decisions

Good tests here assert observable behavior — the count reported, the message/label text produced,
whether `destroy()` and the `_droppedGroups`/`_droppedTemplates` purge fired — not the existence or
internal shape of the shared helper itself.

- **`tests/ci/functional/troop_manager_spec.lua`**, extending the existing `F-036 —
  embarkFromField (extract)` block: mock `getUnits()` to return fewer live units than
  `stored.total` (simulating casualties), including one `SVNT_`-prefixed mock unit among the
  survivors, and assert the extracted logical count reflects the survivors with the servant
  excluded — not `stored.total`. A companion case with zero casualties asserts the count still
  equals the original deploy count (no regression on the common path).

- **`tests/ci/functional/troop_manager_spec.lua`**, new `onUnitDead` describe block (no prior
  coverage exists for this function): a dropped group where the last non-servant unit dies while
  an `SVNT_` unit remains alive must trigger `group:destroy()` and removal from
  `_droppedGroups`/`_droppedTemplates`. A case where a non-last real-troop unit dies must trigger
  neither.

- **`tests/ci/unit/menu_gating_spec.lua`**: extend the existing `_findAllNearbyDropped` stubbing
  pattern used in this file with mock `.group` objects exposing `getUnits()`, and assert the
  rendered command labels match the new formats for both the single- and multi-group cases, and
  that a zero-logical-count entry is absent from what the lookup returns.

- Prior art: `F-036` in `troop_manager_spec.lua` for the mocked-`Group.getByName` pattern used at
  the extraction seam; the existing `_findAllNearbyDropped` stub pattern in `menu_gating_spec.lua`
  for the menu-label seam.

- No DCS live (L3+) integration scenario for this lot — the logic is pure and fully exercised by
  the mocked seams above (agreed with the requester).

## Out of Scope

- Any redesign of the TRZ_ pickup-zone stock model (it tracks unit counts in `src/`, whereas legacy
  tracks whole groups) — the fix's natural effect of restocking by survivor count on return is
  in scope, but reconciling that broader group-vs-unit divergence with legacy is not.
- Any orphan-servant cleanup path other than the reactive `onUnitDead` hook — no periodic sweep,
  and no retroactive cleanup of an orphaned servant already stranded on the map before this fix
  ships (it is cleaned up the next time it takes further unit-death events, or left as-is).
- Vehicle/crate field extraction — this lot is scoped to troop groups only.
- Any change to `maxExtractDistance` or the extraction-radius mechanics themselves.

## Further Notes

- The new/changed menu strings (`"Extract: %1 (%2 troops)"`, `"%1 (%2 troops, %3m)"`) are new i18n
  keys. Run `merge_CTLD.ps1` (which invokes `generate_i18n_dicts.ps1 -Apply`) before opening the
  PR, and check that all four languages (EN/FR/ES/KO) get real translations, not empty stubs.
- `docs/pilot/troop-transport.md` and `.fr.md`, section "Extracting from the field", currently
  document the distance-only label (`Bravo (25m)`) and need updating to the new format.
- `CHANGELOG.md` `[Unreleased]` entry required (this touches `src/`).
