# PRD — UX-CTLD-TOOLS-V2

Status: ready

> Complete redesign of the ctld-tools UI layer: a navigable-catalogue paradigm replacing
> the v1 action-first TUI, and a stack migration from Textual (terminal) to tkinter/sv-ttk
> (native Windows GUI). The business layer (EditModel, Reference, validate, genuser, miz)
> is unchanged.

## Problem Statement

The Mission Maker (MM) using ctld-tools v1 faces three friction points:

1. **Action-first flow.** Every edit starts by choosing an action (Add / Remove / Patch),
   then a type (crate / troop / setting / array). The MM must know what they want to do
   before they can find what they want to change. Discovery is impossible — the tool
   presents no catalogue to browse.

2. **YAML vocabulary leaks into the UI.** "Add", "Patch", "Remove" are YAML-diff concepts
   foreign to an MM who thinks in terms of "I want to change the Humvee troop capacity"
   or "I want to remove the Abrams from my mission".

3. **Terminal UX.** Textual renders in a console window — no native scrollbars, no mouse
   feel, no window chrome that Windows users recognise. MMs who are not developers find
   the tool intimidating before they even click anything.

Additionally, the v1 scope omits `capabilitiesByType` (aircraft transport capabilities) —
one of the most impactful MM-facing settings — and exposes the positional zone arrays
(`troopZones`, `wpZones`, `AIZones`) as opaque lists with no field names.

## Solution

Replace the Textual TUI with a **native Windows GUI** (`tkinter` + `sv-ttk` Sun Valley
theme) built around a **navigable full catalogue**: the MM browses the complete CTLD
default configuration, selects any entry, and edits it in a context-sensitive form. The
concepts Add/Remove/Patch disappear from the interface; the tool resolves the correct
user-config operation transparently.

The layout is a classic master-detail split:

```text
┌─────────────────┬──────────────────────────────┐
│                 │                              │
│   CATALOGUE     │   FORM EDITOR                │
│   TREE          │   (fields + inline widgets)  │
│   (full height) │   + inline validation        │
│                 │                              │
├─────────────────┴──────────────────────────────┤
│ ⚠ 2 errors  │  Save  │  Generate  │  Inject   │
└────────────────────────────────────────────────┘
```

Every field label and every tree node carries a **tooltip** (on hover) drawn from an
extended `CTLD_config_schema.yaml`. The Generate button is disabled while errors remain;
its tooltip explains why.

## User Stories

1. As an MM, I want to open ctld-tools and see a tree of all CTLD configuration
   categories, so that I can discover what is configurable without prior knowledge.

2. As an MM, I want the tree to be collapsed by default showing only the first level,
   so that I am not overwhelmed by hundreds of entries on startup.

3. As an MM, I want to expand "Caisses" and see all crate families (Combat Vehicles,
   Artillery, Support, SAM, Drones) as sub-nodes, so that I can navigate to the crate
   I want to edit.

4. As an MM, I want to click a crate entry (e.g. "Humvee - TOW") and see its attributes
   pre-filled in a form on the right, so that I can edit it without knowing its internal
   YAML structure.

5. As an MM, I want to hover over a form field label and read a short description of
   what that field does and its valid values, so that I never have to consult external
   documentation for basic editing.

6. As an MM, I want to hover over a tree node and read a short description of what that
   section controls, so that I understand the scope before expanding it.

7. As an MM, I want entries I have overridden to appear in bold with a `*` marker in
   the tree, so that I can see at a glance what I have changed relative to the CTLD
   defaults.

8. As an MM, I want entries I have added to appear in a distinct colour (green accent),
   so that I can distinguish my additions from the default catalogue.

9. As an MM, I want entries I have marked for removal to remain visible in the tree
   (struck-through, greyed), so that I can see they exist in the default catalogue and
   restore them if I change my mind.

10. As an MM, I want to click a deleted entry and press "Restore" in the form, so that
    I can undo a removal without hunting through menus.

11. As an MM, I want to click an unmodified scalar (e.g. `numberOfTroops`) and see its
    current default value pre-filled in the form, so that I can change it from a known
    baseline.

12. As an MM, I want the "Delete" button to be absent when a scalar setting is selected,
    so that I am never confused into thinking I can remove a mandatory parameter.

13. As an MM, I want to select the "Combat Vehicles" family node and click "Add entry",
    so that I can create a new crate in that family without knowing its YAML key path.

14. As an MM, I want to configure `capabilitiesByType` for my aircraft (e.g. set
    `maxTroopsOnboard` for the UH-60L), so that CTLD correctly respects my modded
    helicopter's capacity.

15. As an MM, I want to add a completely new aircraft type to `capabilitiesByType`
    (e.g. an OH-6A mod), so that CTLD can manage transport operations for aircraft not
    in the default catalogue.

16. As an MM, I want to remove an aircraft type from `capabilitiesByType`, so that
    CTLD ignores that aircraft in my mission.

17. As an MM, I want the `loadableVehiclesBLUE` field inside an aircraft form to appear
    as an inline list with add/remove controls, so that I can manage the list without
    leaving the form.

18. As an MM, I want the `specificParams` sub-object for drone crates to appear as a
    labelled group of fields within the crate form, so that I can configure drone
    parameters in one place.

19. As an MM, I want to configure `troopZones` entries with named fields (Zone name,
    Colour, Troop limit, Can pickup, Group size), so that I no longer have to count
    positional array indices.

20. As an MM, I want the same named-field experience for `wpZones` and `AIZones`, so
    that all zone types are equally approachable.

21. As an MM, I want a persistent footer with Save / Generate / Inject buttons always
    visible, so that I can trigger global actions without navigating away from my
    current edit.

22. As an MM, I want the Generate button to be visually disabled (greyed) when my
    configuration contains errors, so that I cannot accidentally generate a broken Lua.

23. As an MM, I want the Generate button's tooltip to state how many errors remain,
    so that I know what to fix without scrolling through a separate panel.

24. As an MM, I want a compact validation summary in the footer ("✓ Valid" or
    "⚠ N errors · M warnings"), so that the overall health of my config is always
    in view.

25. As an MM, I want validation errors to appear inline under the relevant form field,
    so that I see exactly which value is wrong while I am editing it.

26. As an MM, I want to press Ctrl+Z and Ctrl+Y to undo and redo my edits, so that
    I can recover from mistakes without reloading the file.

27. As an MM, I want to Save my config to `user-config.yaml` with a single click,
    without being prompted for a file name, so that the workflow stays simple.

28. As an MM, I want to Generate the `CTLD_userConfig.lua` with a single click
    (when valid), without being prompted for a file name, so that I can iterate fast.

29. As an MM, I want to Inject the generated Lua into a `.miz` file by selecting it
    in a file browser that shows only `.miz` files, so that I don't have to add
    MISSION START triggers by hand.

30. As an MM, I want to double-click `ctld-tools.exe` to open the editor directly,
    so that no terminal knowledge is required.

31. As an MM, I want the interface to appear in my system language (EN or FR), so
    that I work in the language I am most comfortable with.

32. As an MM, I want to force the interface language via `--lang en` / `--lang fr`,
    so that I can override the OS locale when needed.

33. As an MM opening the tool for the first time with no `user-config.yaml`, I want
    to see the full catalogue with all default values and no entries marked as modified,
    so that I start from a clear baseline.

34. As an MM reopening the tool on an existing `user-config.yaml`, I want to see my
    previously saved modifications already reflected in the tree (bold/green/strikethrough),
    so that I can continue editing where I left off.

35. As an MM, I want to manage `transportPilotNames`, `extractableGroups` and
    `logisticUnits` as simple add/remove string lists within their tree sections,
    so that I can assign pilot slots and group names without editing YAML directly.

36. As an MM, I want to manage `groundVehicleWeights` entries (vehicle type → weight)
    with add/modify/remove, so that slingload weight limits reflect my modded vehicles.

## Implementation Decisions

### Stack: Textual → tkinter + sv-ttk

The Textual TUI (`tui/app.py`, `tui/forms.py`, `tui/widgets.py`) is fully replaced by a
tkinter application styled with the `sv-ttk` Sun Valley theme. `sv-ttk` is added as a
runtime dependency of `ctld_tools`. `textual` moves to the optional / legacy group or is
removed entirely.

`ttk.Treeview` provides the catalogue tree with native scrollbars, expand/collapse and
row selection. The form panel is a scrollable `ttk.Frame` on the right. The footer is a
fixed-height `ttk.Frame` pinned at the bottom.

The `.exe` build (PyInstaller) targets Windows (~15–20 MB). The double-click launch
bridge (`__main__.py` → `tui` command) is preserved. Running from source via
`poetry run ctld-tools` works on macOS and Linux; the `sv-ttk` theme is functional on
all platforms but optimised for Windows.

### Catalogue view vs diff view

The tree always shows the **full CTLD default catalogue** (sourced from `Reference`,
same as today), not only the MM's operations. The `EditModel` continues to store
operations (add/patch/remove) as the diff structure — that contract is unchanged.

The tree renderer computes the display state of each entry by merging the catalogue with
the current `EditModel.config` at render time:

- entry present in catalogue only → state `default`
- entry overridden in `EditModel` → state `modified`
- entry added by MM (not in catalogue) → state `added`
- entry in catalogue but marked for removal in `EditModel` → state `deleted`

Four visual states in `ttk.Treeview` rows (via tags):

| State | Tag style |
| --------- | -------------------------------------------- |
| `default` | Normal weight, default foreground |
| `modified` | Bold, default foreground, `*` suffix on label |
| `added` | Normal weight, green foreground |
| `deleted` | Overstrike font, grey foreground |

### Tree structure

Top-level nodes (i18n keys provided for EN/FR):

```text
Parameters
  ├── Standard        ← mm_facing scalars
  └── Advanced        ← advanced scalars
Crates                ← spawnableCrates (family sub-nodes)
  ├── Combat Vehicles
  ├── Artillery
  ├── Support
  ├── SAM short range
  └── Drones
Troop Groups          ← loadableGroups
Aircraft              ← capabilitiesByType  ← NEW in v2
Zones
  ├── Troop Zones     ← troopZones (named fields)
  ├── Waypoint Zones  ← wpZones (named fields)
  └── AI Zones        ← AIZones (named fields)
Mission Lists         ← transportPilotNames, extractableGroups, logisticUnits
Advanced
  ├── Vehicle Weights ← groundVehicleWeights
  └── Mod Types       ← modTypes
```

### Form panel

The form panel is context-sensitive to the selected tree node:

- **Scalar (Type A)** — one labelled field; `Apply` + `Cancel`; no `Delete`.
- **Named object (Type B-1)** — one labelled field per attribute; `Apply` + `Delete` +
  `Cancel`. For default entries, `Delete` marks the entry for removal. For added entries,
  `Delete` removes the addition. For deleted entries, the form shows `Restore` instead.
- **List-of-strings attribute** within an object form (e.g. `loadableVehiclesBLUE`) —
  rendered as an inline list widget: current items displayed with a `×` button each, plus
  an `+` input row. No sub-navigation.
- **Sub-object attribute** within an object form (e.g. `specificParams`) — rendered as a
  labelled group of fields inline. No sub-navigation.
- **B-2 list entry** (e.g. item in `transportPilotNames`) — simple text field; `Apply` +
  `Delete` + `Cancel`.
- **B-3 zone entry** (`troopZone`, `wpZone`, `AIZone`) — fields presented by name (Zone
  name, Colour, Troop limit, Can pickup, Group size, Icon ID) mapped from the positional
  array schema; `Apply` + `Delete` + `Cancel`.
- **"Add entry" context** (family node selected, Add button clicked) — blank form for
  the appropriate object type; `Add` + `Cancel`.

Field focus within the form triggers an inline description drawn from
`CTLD_config_schema.yaml`. Tooltip on hover of the field label provides the same
description persistently.

### Form commit model

Editing in the form is a **transaction**: the MM fills one or more fields, then clicks
`Apply` to commit the change to the in-memory `EditModel`, or `Cancel` to discard. There
is no auto-save on field exit — accidental keystrokes do not take effect until `Apply` is
clicked. `Cancel` restores the form to the last committed state.

Two distinct levels of persistence:

1. `Apply` → commits the operation to `EditModel` (in-memory, undoable via Ctrl+Z).
2. `Save` (footer) → serialises `EditModel.config` to `user-config.yaml` on disk.

### Tooltips

`tkinter` tooltips are implemented via a lightweight custom helper that binds `<Enter>`
/ `<Leave>` on any widget and displays a `tk.Toplevel` label near the cursor. Applied to:

- Tree row labels (hover → node/entry description)
- Form field labels (hover → field description)
- Footer buttons (Generate → error count when disabled)

### CTLD_config_schema.yaml extension

The schema currently holds descriptions for the ~73 scalar settings. It must be extended
to cover:

- All attributes of `spawnableCrates` entries (`unit`, `desc`, `weight`, `cratesRequired`,
  `side`, `isJTAC`, `spawnAs`, `specificParams` and its sub-fields)
- All attributes of `loadableGroups` entries (`name`, `inf`, `mg`, `at`, `aa`, `mortar`,
  `jtac`)
- All attributes of `capabilitiesByType` entries (all ~12 fields)
- Named fields of `troopZones`, `wpZones`, `AIZones` positional arrays
- Section-level descriptions for each top-level tree node

The schema remains the single source of truth for authoring metadata. The GUI reads it
via the existing `Reference` API; `Reference` gains accessors for the new field types.

### capabilitiesByType scope

Full add / modify / remove:

- **Modify**: select an existing aircraft (e.g. "UH-60L") → edit any of its ~12 attributes.
- **Add**: click "Add entry" on the Aircraft node → blank form; `unit` field resolved
  against the DCS type set (datamine) via a filterable picker (same as the crate `unit`
  field in v1).
- **Delete**: marks the aircraft for removal in the user-config.

### Undo / Redo

Unchanged. `EditModel` already maintains `_undo` / `_redo` stacks via `_checkpoint()`.
The GUI binds `Ctrl+Z` → `model.undo()` and `Ctrl+Y` → `model.redo()` and redraws the
tree + form after each call. No change to `EditModel`.

### Footer

A `ttk.Frame` pinned below the main paned window, never scrolled away:

- Left: validation status label (updates on every `EditModel` mutation)
- Right: `Save`, `Generate` (disabled when `not model.can_generate`), `Inject`

`Inject` opens a `tkinter.filedialog.askopenfilename` filtered to `*.miz`, then calls
the existing `miz.inject_userconfig`.

### CLI

The `tui` command in `cli.py` now calls the tkinter app's `run()`. All other commands
(`validate`, `gen-user`, `gen-config`, `inject`, `gen-reference`) are unchanged.

### i18n

The existing `ctld_tools.i18n` module and `t()` helper are unchanged. New i18n keys are
added for tree node labels, form section headers, button labels, and tooltip fallbacks.

## Testing Decisions

**What makes a good test here:** test observable behaviour (tree state after an operation,
form field values after a selection, footer status after a mutation), not widget
internals. Drive the `EditModel` directly for logic tests; use tkinter's `after(0, …)`
or a headless test facade for widget tests.

**Modules and seams:**

- `test_editmodel.py`, `test_validate.py`, `test_genuser.py`, `test_reference.py`,
  `test_miz.py` — **unchanged**. These test the business layer, which is not touched.

- `test_app.py`, `test_widgets.py`, `test_forms.py` — **rewritten** for the tkinter
  layer. The tkinter equivalent drives the app via `app.after(0, …)` event-loop injection
  or a synchronous test facade that calls the underlying model methods and inspects tree
  tags / form field values directly.

- **New: `test_catalogue_tree.py`** — verifies that the tree renderer correctly computes
  the four display states (default / modified / added / deleted) by comparing tree row
  tags against a known `EditModel.config`.

- **New: `test_schema_coverage.py`** — asserts that every field of every table type has
  a description entry in `CTLD_config_schema.yaml`, preventing silent tooltip blanks.

- **New: `test_zone_fields.py`** — verifies that positional `troopZone` / `wpZone` /
  `AIZone` arrays round-trip correctly through the named-field form (field names →
  positional write → positional read → field names).

Prior art: `test_cli_bridge.py` (exercises the CLI entry point without a running app)
provides the closest existing seam for headless GUI integration.

## Out of Scope

- Any change to `EditModel`, `Reference`, `validate`, `genuser`, `miz`, `cli` (business
  layer is frozen for this lot).
- Adding new languages or translating dictionaries.
- Generating documentation tables from the schema (see `dev/roadmap.md`).
- Deprecating the companion `CTLD_asset_check.lua` (see `dev/roadmap.md`).
- `modTypes` validation against `user-config` declared types (see `dev/roadmap.md`).
- Any change to `src/` Lua or the build pipeline.

## Tickets

| # | Title | Blocked by |
| -- | ----- | ---------- |
| 01 | Foundation: tkinter shell + sv-ttk + tooltip helper | — |
| 02 | Scalars editor: full end-to-end | 01 |
| 03 | Crates editor (spawnableCrates) | 02 |
| 04 | Troop groups editor (loadableGroups) | 02 |
| 05 | Aircraft editor (capabilitiesByType) | 02 |
| 06 | Zone editors with named fields | 02 |
| 07 | Mission lists + vehicle weights | 02 |
| 08 | Schema full coverage + test_schema_coverage | 03–07 |

Tickets 03–07 are parallelisable after 02.

## Further Notes

- Branch convention: `feature/ux-ctld-tools-v2`.
- `sv-ttk` must be declared in `tools/ctld-tools/pyproject.toml` as a runtime dependency
  and pinned. The PyInstaller spec must include the `sv-ttk` data files (themes).
- The existing `CTLD-TOOLS-TUI-POLISH` lot (merged PR #55) delivered descriptions for
  scalars in the schema; this lot extends that coverage to all table fields.
- `capabilitiesByType` add uses the same DCS-type filterable picker already implemented
  for crate `unit` in v1; reuse the widget logic.
- A golden test asserting that the `reference.json` bundle covers all tables accessible
  in the v2 tree should be added alongside `test_schema_coverage.py`.
