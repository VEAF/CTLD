Status: ⬜ ready

# PRD — UX-FOB-ALLCRATES-CRATE-COUNT

## Problem Statement

Two related gaps in the "Request Equipment" experience for transport pilots:

1. **FOB scenes have no "All crates" entry.** FOB construction requires 3 identical crates, but
   `fobScene.crate` has `showSets = false`, suppressing the auto-generated `singleTypeSet`.
   A pilot must request and transport each crate individually with no shortcut to order all three
   at once — unlike every other multi-crate equipment in the catalogue.

2. **No crate-count indication in "Request Equipment".** The menu label for any equipment (vehicle,
   scene, AA part) never tells the pilot how many crates are required. A pilot has no way to know
   whether an item needs 1 or 3 crates before attempting to pick it up, forcing trial-and-error
   or external documentation lookup.

## Solution

1. **Enable "All crates" for FOB scenes** by removing `showSets = false` from the FOB scene
   crate descriptor. The existing `singleTypeSet` auto-generation already handles the rest.

2. **Suffix `(xN)` to every "Request Equipment" label**, where N is `cratesRequired` for that
   entry. The suffix is always shown (including `(x1)` for single-crate items) for total
   consistency. The format uses ASCII `(xN)` for DCS compatibility.

## User Stories

1. As a transport pilot, I want to request all FOB crates in one click, so that I do not have to
   request each of the 3 crates individually before a FOB build.
2. As a transport pilot, I want to see `(x3)` next to "FOB Crate" in Request Equipment, so that
   I know before departing how many crates the FOB requires.
3. As a transport pilot, I want to see `(x1)` next to single-crate equipment, so that I have a
   consistent reading of the menu and never wonder whether an absent indicator means 1 or unknown.
4. As a transport pilot, I want to see the crate count on every equipment entry (vehicles, scenes,
   AA parts), so that I can plan my sortie without consulting external documentation.
5. As a transport pilot, I want to see `(xN)` on the individual entry and not on the "All crates"
   entry, so that the label tells me the per-trip cost rather than duplicating what "All crates"
   already implies.
6. As a mission maker, I want the FOB "All crates" entry to appear automatically when `enableAllCrates`
   is true, so that I do not need to configure anything extra.
7. As a mission maker, I want the crate-count suffix to appear in i18n-translated labels, so that
   FR/ES/KO missions benefit from the same UX improvement.

## Implementation Decisions

- **FOB fix**: remove `showSets = false` from `fobScene.crate`. The field defaults to `true`
  when absent, which is the correct behaviour for a multi-crate scene.

- **Crate-count suffix**: the `(xN)` suffix is appended at the point where `desc` is constructed
  from `i18nKey` / `unit`, not at the point where the menu label is rendered. This means:
  - `_injectSceneCrate()`: suffix applied when building `entry.desc` from `cd.i18nKey`.
  - `_processSpawnableCrates()`: suffix applied when building `entry.desc` from catalogue YAML
    entries (both `singleCrate` and `mixedSet` paths are left untouched — only `singleCrate.desc`
    gets the suffix since it is the per-unit entry).
  - The "All crates" `singleTypeSet.desc` is derived from `entry.desc` after the suffix is
    applied, so it will read e.g. `"FOB Crate (x3) - All crates"`. This is acceptable; if the
    project later decides to strip the suffix from "All crates" labels, that is a separate lot.
  - `mixedSet` entries (AA "All crates" from YAML) are not modified — they already have their
    own explicit `desc`.

- **Format**: `" (x" .. cr .. ")"` appended to `desc`, where `cr = cratesRequired or 1`. ASCII
  only, no Unicode multiplication sign.

- **Always shown**: the suffix is unconditional — `cratesRequired = 1` produces `(x1)`.

- **i18n**: the suffix is appended after translation (`ctld.tr(i18nKey)`) so it is language-
  agnostic and does not require new i18n keys.

## Testing Decisions

A good test asserts the externally observable label that reaches the menu, not the internal
field that carries it.

**L1 busted — `_processSpawnableCrates`:**
- Assert that a catalogue entry with `cratesRequired = 1` produces a `singleCrate.desc` ending
  in `" (x1)"`.
- Assert that a catalogue entry with `cratesRequired = 3` produces a `singleCrate.desc` ending
  in `" (x3)"`.
- Prior art: `tests/ci/unit/crate_manager_spec.lua`.

**L1 busted — `_injectSceneCrate`:**
- Assert that a scene crate with `cratesRequired = 1` produces a desc ending in `" (x1)"`.
- Assert that a scene crate with `cratesRequired = 3` (FOB) produces a desc ending in `" (x3)"`
  and that a `singleTypeSet` is generated (FOB "All crates" enabled).
- Prior art: `tests/ci/unit/deploy_managers_spec.lua`.

## Out of Scope

- Stripping `(xN)` from the "All crates" `singleTypeSet.desc` — the suffix on the base `desc`
  propagates to it; this is accepted and deferred.
- Showing crate count in the "Unpack Crate" submenu (that menu is driven by crates already on
  the ground; count is implicit from the entry being visible).
- Showing crate count for `mixedSet` entries (AA "All crates" from YAML).
- Any change to the "Load Crate" submenu.

## Further Notes

`showSets = false` was set on the FOB crate at a time when the auto-generation logic may have
had different behaviour or the FOB unpack path had different constraints. No ADR documents the
intent. Removing it aligns the FOB with every other multi-crate equipment.
