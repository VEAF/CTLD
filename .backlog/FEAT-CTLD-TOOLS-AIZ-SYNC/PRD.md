# FEAT-CTLD-TOOLS-AIZ-SYNC — `ctld-tools` reads a mission's zones to populate and sync the AIZ_ editor

**Status:** open.

Formalizes the `grill-with-docs` session (2026-09-23) on `dev/roadmap.md`'s "`ctld-tools` — lire
les zones du `.miz` pour peupler et synchroniser l'éditeur AIZ_" entry, opened while a.lingo was
about to manually re-enter `AIZ_` zone parameters into `ctld-tools` for `FEAT-EXZ-AUTODISCOVERY`
ticket 01. Conclusions are recorded in that roadmap entry and in `CONTEXT.md`'s "Zones" section
(the new "Tool-only naming convention" glossary entry, distinct from "Auto-discovered zone" and
"Config-referenced zone"). This PRD does not re-derive those decisions — it formalizes them.

This is a `ctld-tools` (Python/FastAPI backend + Svelte frontend, `tools/ctld-tools/`) feature.
**No `src/` (Lua engine) change is in scope** — the grill's Decision 1 explicitly rules out
engine-side parsing of the naming convention this PRD adds.

## Problem Statement

1. A Mission Maker configuring `AIZ_` zones in `ctld-tools` has to type `dcsZoneName` as free
   text, with zero validation against the mission's real trigger zones — a typo is only caught
   at DCS mission-start, not while authoring.
2. When a Mission Maker's own zone-naming habit already encodes coalition, pickup/dropoff, and
   cargo type in the DCS zone name (as `Test_CTLDNEXT_01.miz`'s zones already do, e.g.
   `AIZ_depot_B_P_V_10`), CTLD never reads any of it — the engine only ever consults the explicit
   `aiZones` config entry. The Mission Maker re-types the same facts a second time, with the
   drift/error risk that implies, and has no way to keep the config in step as zones are added to
   or removed from the mission over time.

## Solution

1. `ctld-tools` gains the ability to read a mission's actual DCS trigger-zone names back, and
   offers them as autocomplete on `dcsZoneName` — independent of any naming convention, useful for
   every zone kind the editor handles.
2. For zones already following a partial `AIZ_<name>_<coalition>_<P|D>_<cargoType-or-aiDropMode>`
   naming convention, `ctld-tools` recognises it (itself only — the CTLD engine never does) and
   keeps the `aiZones` config in sync with the mission's real zone list: adding a config entry,
   pre-filled with the parseable fields, for every matching zone that doesn't have one yet, and
   proposing (with a confirmation recap, never silently) the removal of a config entry whose
   matching zone has been deleted from the mission. The rich per-template/per-type stock fields
   stay entirely the Mission Maker's own job to fill in inside `ctld-tools`.

## User Stories

1. As a Mission Maker, I want `dcsZoneName` to suggest real zone names from my mission as I type,
   so that a typo is caught immediately instead of at DCS mission-start.
2. As a Mission Maker who names my AI zones with a coalition/pickup-dropoff/cargo-type convention
   already, I want `ctld-tools` to recognise that and create the matching config entry for me, so
   that I don't retype facts my zone name already states.
3. As a Mission Maker, I want the pre-filled entry to clearly show it still needs the stock table
   filled in, so that I don't mistake it for a finished, working zone.
4. As a Mission Maker who deletes a zone from the Mission Editor, I want `ctld-tools` to notice
   its config entry is now orphaned and offer to remove it, so that my configuration doesn't
   accumulate references to zones that no longer exist.
5. As a Mission Maker, I want that removal to always show me what's about to be deleted and ask
   for confirmation first, so that scanning the wrong mission by mistake can't silently destroy
   stock configuration I already spent time writing.
6. As a Mission Maker, I want a zone I named and configured entirely by hand (not following the
   `AIZ_` convention) to never be touched by this sync — added, removed, or otherwise — so that
   the feature never surprises me on config I own outside of it.
7. As a Mission Maker, I want re-scanning to never overwrite a config entry that's already there,
   whether or not I've finished filling in its stock, so that re-checking for new zones is always
   a safe, non-destructive action.
8. As a Mission Maker, I want to choose which `.miz` to scan via the same native file-picker the
   rest of the tool already uses, so that the workflow feels consistent with the rest of the app.
9. As a Mission Maker, I want the tool to notice on its own when the mission file has changed
   since the last scan (without me having to remember to click anything), so that my config and
   my mission don't quietly drift apart between sessions.
10. As a Mission Maker, I want to still be able to force a re-check or point the tool at a
    different mission file whenever I want, so that automatic detection is a convenience, not a
    constraint.
11. As a Mission Maker who is only editing an already-loaded configuration and has no new zones
    to import, I want to keep using the AI-zones editor without being forced to pick a mission
    file first, so that the scan/import feature's own requirement doesn't get in the way of
    unrelated edits.
12. As a developer reading `CTLD_zone.lua` or `docs/mission-maker/zones.md`, I want no trace of
    this convention in the engine or its Mission-Maker docs, so that it's unambiguous this is a
    `ctld-tools`-only authoring convenience, not a new CTLD zone-discovery mechanism.

## Implementation Decisions

- **Zone-name reading**: a new backend capability reads the tracked mission's
  `env.mission.triggers.zones` (via the existing `miz.read_mission()`, already used for injection)
  and returns every zone name. Wired into `AiZonesEditor`'s `dcsZoneName` field as a `<datalist>`,
  mirroring the pattern the troop-template stock field already uses for its own autocomplete.
- **Session/mission-path scope, resolved during PRD drafting**: today, `Session.mission_path` is
  only ever set as a side effect of `load_path()` opening a configuration **already installed**
  inside a `.miz` (`install.read_config()` raises when none exists) — a real constraint the grill
  didn't examine, and one that would reject exactly the case that motivated this PRD
  (`Test_CTLDNEXT_01.miz` has never had a `ctld-tools` config installed; it loads the engine via
  the `CTLD_DEV_ROOT` dev shortcut instead). The new "choose a mission to scan" action is therefore
  a **separate entry point** that sets the same `session.mission_path` field directly, without
  requiring a pre-existing installed configuration — the field keeps its single meaning (per the
  grill's decision: one mission notion, not two), but gains a second way to be set. Reuses the
  existing native picker (`dialogs.pick_miz`) unchanged.
- **Naming convention (`ctld-tools`-only, never engine-level)**:
  `AIZ_<name>_<coalition>_<P|D>_<cargoType-or-aiDropMode>`, parsed strictly left-to-right —
  `name` (free text), `coalition` (`R`/`B`/`N`), `P` or `D`, then a 4th field read as `cargoType`
  (`T`/`V`/`TV`) when the 3rd was `P`, or `aiDropMode` (`G`/`P`/`GP`) when the 3rd was `D`. Any
  content beyond the 4th field (e.g. the legacy stock-number suffix already present in real zone
  names like `AIZ_depot_B_P_V_10`) is ignored, not rejected, so already-named zones parse without
  renaming anything. `src/CTLD_zone.lua` is not touched — the engine has no notion of this
  convention; it only ever reads `ctld.gs("aiZones")`.
- **Reconciliation, triggered by the picker action AND automatically** (mtime of the tracked
  mission compared against the value at last scan, checked when the AI-zones editor tab becomes
  active — no persistent file-system watcher; this is a local, single-user desktop app):
  - *Additions* (silent, no confirmation needed): every zone matching the naming convention with
    no existing `aiZones` entry for that exact `dcsZoneName` gets one created, the 4 parseable
    fields filled in, `troopStock`/`vehicleStock` left **absent** (not an empty table) —
    deliberately reusing the existing "pickup zone missing stock" validation warning as the
    already-built "still needs attention" signal, rather than inventing a new UI marker.
  - *Removals* (never silent): an existing entry is proposed for removal only when **both** its
    `dcsZoneName` matches the naming convention **and** that exact zone is absent from the
    freshly-scanned mission. Shown as a recap ("N zones will be removed because they no longer
    exist in the mission") the Mission Maker must confirm before it's applied.
  - *Never touched*: an entry already present (regardless of whether its stock fields are filled
    in) is never overwritten by a re-scan. An entry whose `dcsZoneName` does not match the naming
    convention is never added or removed by this feature, no matter what happens to its zone in
    the mission — that stays `ctld-tools validate`'s job, untouched by this PRD.
  - The "must pick a mission first" requirement is scoped to triggering a scan/import pass —
    viewing or editing an already-loaded configuration's existing `aiZones` entries never requires
    a mission to be selected.

## Testing Decisions

- `tools/ctld-tools/tests/test_miz.py` (pytest) is the existing seam for `miz.py`-level
  mission-reading logic — extend it for the new zone-name-listing capability (round-trips a
  generated mission fixture, same style as the existing `inject_userconfig` tests there).
- `web/src/lib/AiZonesEditor.test.ts` (vitest + testing-library/svelte) is the existing seam for
  the editor component — extend it for: the naming-convention parser (well-formed names, the
  context-dependent 4th field, tolerance of a trailing legacy suffix, rejection/non-match of a
  malformed name), the datalist wiring, and the reconciliation logic (additions applied silently,
  removals requiring confirmation, already-present entries never overwritten, non-matching
  `dcsZoneName` entries never touched). Only external behaviour is asserted — the rendered
  fields/options and the `onchange` payload, not internal component state — matching this file's
  existing style (see the `coalition`-round-trips-as-a-string test already there).

## Out of Scope

- Any change to `src/CTLD_zone.lua` or the CTLD engine — the naming convention is recognised by
  `ctld-tools` only (grill Decision 1).
- Extending this naming convention, or an equivalent one, to any other zone kind (`TRZ_`, `LGZ_`,
  `WPZ_`, `EXZ_`) — those are already engine-auto-discovered and out of this PRD's problem.
- `ctld-tools validate`'s existing checks for a freely-named (non-`AIZ_`) entry whose zone has
  disappeared — untouched, already covers that case on its own terms.
- A persistent file-system watcher for the mission file — mtime comparison on tab-activation is
  the agreed mechanism; no background process.
- Reading or suggesting `troopStock`/`vehicleStock`/`troopTemplates`/`vehicleTypes` from anything
  in the mission — these are never encoded in a zone name and stay entirely manual.

## Further Notes

- **ADR candidate**: Decision 1 (the naming convention is `ctld-tools`-only, never engine-level)
  is hard to reverse once Mission Makers rely on the pre-fill, surprising without context ("why is
  `EXZ_` auto-discovered by the engine but not `AIZ_`?"), and the result of a real trade-off
  already argued out in the grill (an engine-parsed partial convention would permanently trigger
  the existing stock-missing warning by construction, and reintroduce two sources of truth for the
  same zone). Write it as an ADR during the implementing ticket, the same way
  `FEAT-EXZ-AUTODISCOVERY` ticket 02 produced ADR 0016 rather than during this PRD.
- The full grill record — including the `session.mission_path` constraint found while drafting
  this PRD — lives in `dev/roadmap.md`'s "`ctld-tools` — lire les zones du `.miz`..." entry and
  `CONTEXT.md`'s "Zones" section. Read both before breaking this PRD into tickets.
