# CTLD-TOOLS-TUI

**Status:** ✅ merged (PR #52). Compacted from `CTLD-TOOLS-TUI/` on 2026-08-01; the ticket files live on in git history.

Interactive **textual** TUI for `ctld-tools` ([ADR 0009](../dev/adr/0009-external-yaml-authoring-ctld-tools.md)): a MM console that structurally edits the `user-config.yaml`, validates live, and generates/injects — all in one screen, with filter-as-you-type pickers, add/remove/patch + edit/delete of entries, undo/redo, settings help (defaults + bool/enum lists via `src/CTLD_config_schema.yaml`), unsaved-changes guard and a `.miz` file browser. **Embedded reference** (bundled from `src/`) makes `--src` optional and moves **lupa build-time-only** (exe drops it). **i18n EN+FR** (OS locale + `--lang`). Runtime gains `ctld.patchTroopGroup`. Model separated from UI for pure unit tests + Pilot smoke. modTypes/companion out of scope (separate lot).

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-embedded-reference` | ✅ done | 01 — Embedded reference catalogue (lupa build-time-only) |
| `02-edit-model` | ✅ done | 02 — User-config edit model (pure, testable) |
| `03-filter-picker` | ✅ done | 03 — Filterable picker (filter logic + widget) |
| `04-textual-tui` | ✅ done | 04 — Textual TUI app (the console) |
| `05-cli-and-packaging` | ✅ done | 05 — `tui` command + packaging (exe without lupa) |
| `06-docs-changelog-index` | ✅ done | 06 — Docs, CHANGELOG, index |

## PRD

Status: done

## PRD — CTLD-TOOLS-TUI

> Interactive TUI for `ctld-tools` (the roadmap item). See [ADR 0009](../../dev/adr/0009-external-yaml-authoring-ctld-tools.md).
> Cadré via grill-with-docs (2026-07-20).

### Problem Statement

`ctld-tools` lets a Mission Maker (MM) configure CTLD from a `user-config.yaml` and generate the
`CTLD_userConfig.lua`. But the target MM is **non-technical**: hand-writing YAML (even the commented
scaffold) and chaining CLI commands (`validate`, `gen-user`, `inject`) is still intimidating. Two
concrete pain points:

- Writing YAML by hand is error-prone and unfamiliar; the MM does not know which crates, troop groups
  or DCS unit types exist without reading source or dumping logs.
- The tool only reaches the MM as `ctld-tools.exe` — which today needs the CTLD `src/` folder to
  resolve names (`--src`), a folder a non-dev MM does not have.

### Solution

A **console TUI** (`ctld-tools tui`, built with **textual**) that is the MM's single entry point:
a structured editor of the `user-config.yaml` that **validates in real time**, then **generates** and
optionally **injects** — all without leaving the screen or writing YAML.

- **Structured editor**: shows the current config by section (`settings`, `crates` add/remove/patch,
  `troops` add/remove, `arrays`), and lets the MM add / remove / edit one entry at a time through
  guided forms. Existing files open for editing; the YAML is rewritten cleanly on save.
- **Guided by the catalogue**: forms use **filter-as-you-type pickers** for large lists — DCS unit
  types (~1143), and crates/troop groups from the catalogue — so the MM selects, never memorises.
- **Live validation**: every edit is validated against the reference catalogue + DCS type set, with
  inline errors and suggestions.
- **All-in-one**: from the TUI the MM can generate `CTLD_userConfig.lua` (`gen-user`) and inject it
  into a `.miz` (`inject`).
- **Embedded reference**: the catalogue is **bundled in the package** (generated from `src/` at build
  time), so the MM needs **only the `.exe`** — no `src/`. This makes `--src` an optional dev override
  across the tool, and moves **lupa to build-time only** (the MM `.exe` no longer bundles it).

### User Stories

1. As a non-dev MM, I want to launch a single interactive tool (`ctld-tools tui`), so that I configure
   CTLD without writing YAML or chaining commands.
2. As an MM, I want the TUI to open with only the `.exe` (no CTLD `src/`), so that I don't need the
   repository.
3. As an MM, I want to see my current config laid out by section, so that I understand what I've set.
4. As an MM, I want to open an existing `user-config.yaml` and edit it, so that I refine over time.
5. As an MM, I want to start a fresh config when none exists, so that I begin from empty.
6. As an MM, I want to add a crate through a form, so that I don't hand-write the entry.
7. As an MM, I want to pick the crate's `unit` from a **filterable** list of DCS types (type to
   narrow ~1143 down), so that I find it fast and never mistype it.
8. As an MM, I want to remove a crate by picking it **by name** from a filterable list of the
   catalogue, so that I don't look up weights.
9. As an MM, I want to edit (patch) one field of an existing crate via a form, so that I change one
   thing without rewriting it.
10. As an MM, I want to add / remove a troop group by name (filterable), so that I curate the troops
    menu.
11. As an MM, I want to set scalar settings (e.g. `numberOfTroops`) through labelled inputs, so that I
    don't guess YAML keys.
12. As an MM, I want to append array-setting entries (`transportPilotNames`, `troopZones`, …) via a
    form, so that I extend lists safely.
13. As an MM, I want each edit validated **as I make it**, with a clear error and suggestion (unknown
    crate name, unknown/ambiguous target, invalid `unit`, colliding weight), so that I fix mistakes
    immediately.
14. As an MM, I want to save my edits to `user-config.yaml`, so that I keep my work.
15. As an MM, I want to generate `CTLD_userConfig.lua` from within the TUI, so that I don't switch to
    the CLI.
16. As an MM, I want to inject the generated Lua into a `.miz` from the TUI (picking the mission
    file), so that I finish end to end in one place.
17. As an MM, I want the TUI to refuse generation while there are validation errors, so that I never
    ship a broken config.
18. As an MM using a filterable picker, I want the filter to be case-insensitive substring matching,
    so that partial text finds the entry.
19. As a CTLD developer, I want `validate` / `gen-user` to work without `--src` (using the embedded
    reference), so that the tooling is usable outside the repo; `--src` stays as an override.
20. As a CTLD developer, I want the embedded reference generated from `src/` at build time and kept in
    sync, so that it matches the real catalogue (including AA crates).
21. As a CTLD maintainer, I want the MM `.exe` to no longer bundle lupa, so that packaging is lighter
    and free of the native Lua binary; lupa stays for build-time reference generation.
22. As a CTLD developer, I want the edit logic (state + operations + live validation + filtering) in a
    **model separate from the textual UI**, so that it is unit-tested without widgets.

### Implementation Decisions

- **textual** app, launched by a new `ctld-tools tui` sub-command (no args needed; embedded reference
  by default, optional `--yaml` to open a file, optional `--src` dev override).
- **Model / UI separation**: a pure **edit model** holds the `user-config` state and exposes the
  operations (add/remove/patch crate, add/remove troop, set scalar, append array) plus **live
  validation** (reusing the existing `validate`) and the **picker filter** (case-insensitive
  substring). The textual layer is a thin view/controller over it. All non-UI logic is unit-testable.
- **Embedded reference (catalogue)**: a new build step (`gen-reference`, lupa) produces a bundled
  data file (crates incl. AA + troop groups + array-setting names + crate name→weight index) from
  `src/`. `Reference` gains `from_embedded()` (reads the bundle), which becomes the **default** for
  the TUI, `validate` and `gen-user`; `--src` → `from_src` remains an override. **lupa moves to the
  `build`/dev dependency group** — the MM `.exe` no longer imports it at runtime.
- **Filterable pickers**: any picker over a non-trivial list (DCS types, catalogue crates/troops)
  filters as the MM types (a text input driving a filtered option list). Exact textual widget chosen
  at implementation.
- **Save / generate / inject** are TUI actions calling the existing `render_user_config` /
  `inject_userconfig`; generation is blocked while validation has errors.
- **YAML** is rewritten cleanly on save (no comment preservation) — the TUI is the editing surface.
- **Packaging**: `release.yml` builds the `.exe` with textual bundled; the reference bundle is
  generated (or committed, consistent with gen-au-build) before packaging. Verify textual runs from a
  PyInstaller one-file build.
- **ADR**: record the embedded-reference / lupa-build-time-only shift as a note on ADR 0009 (or ADR
  0010).

### Testing Decisions

Good tests assert observable behaviour at the **highest seam** — the edit model's state/findings and
the reference resolution — not textual widget internals. Prior art: the existing `ctld-tools` pytest
suite; dcs-bridge's `test_client_tui.py` for the textual `app.run_test()` + Pilot pattern.

- **`Reference.from_embedded` + `gen-reference`** (pytest, pure): `from_embedded()` resolves
  identically to `from_src()` (parity, AA included); `validate`/`gen-user` run with no `--src`; a
  golden check on the generated bundle.
- **Edit model** (pytest, pure): each operation (add/remove/patch crate, add/remove troop, set
  scalar, append array) applied to the state yields the expected state and findings; generation
  refused while errors exist. This is where the logic lives.
- **Picker filter** (pytest, pure): input string → expected narrowed list (case-insensitive
  substring).
- **TUI smoke** (pytest-asyncio, `app.run_test()` + Pilot): the app starts; a scripted scenario (add
  a crate through the UI) reaches the expected model state / save. Thin — proves the UI↔model wiring,
  not every widget.

`pytest-asyncio` is added to the dev dependencies for the Pilot test.

### Out of Scope

- **`modTypes` validation** (accepting MM-declared mod types) and **deprecating the asset-check
  companion** — a separate lot (noted in `dev/roadmap.md`). Until then the TUI shares the current
  limitation: a mod `unit` not in the stock datamine is flagged.
- Types injected only at runtime (plugin scenes) — not visible design-time; covered by the in-DCS
  test.
- Any change to the `user-config.yaml` schema or the runtime API.
- Comment-preserving round-trip of the YAML.

### Further Notes

- The embedded-reference shift benefits the whole tool (usable without `src/`), not just the TUI, and
  is the prerequisite ticket.
- Only ctld-tools roadmap item after this: none — `modTypes`/companion is the follow-up lot above.

### Amendment (2026-07-21, post-first-run review)

After trying the TUI, four enhancements were agreed and folded into the same lot/PR:

1. **i18n (EN + FR)** following the OS language, forced by `--lang` / `CTLD_LANG` — modelled on VMCT
   (stdlib layer, flat JSON catalogs). Covers the TUI **and** the validation findings.
2. **Undo / redo** in the edit model (snapshot stack), bound to Ctrl+Z / Ctrl+Y.
3. **Delete a tree entry** (with confirmation) — distinct from the catalogue-level `remove`.
4. **Patch troop group** — adds a `ctld.patchTroopGroup` runtime helper (this **intentionally
   extends the runtime API**, superseding the "no runtime API change" line above for this one
   symmetric helper) and a 3-button **Add / Remove / Patch → type chooser** ergonomics.
5. **Settings help** — Set setting is a filterable picker over the ~108 scalar settings, showing and
   pre-filling each default; unknown settings are flagged (warning). The embedded reference bundle
   gains `scalarSettings` (name → default).
6. **Value pickers for settings** — booleans and fixed-value settings are chosen from a list (not
   typed). Allowed values come from a new **authoring schema** `src/CTLD_config_schema.yaml`
   (additive, NOT consumed by the build — keeps gen-config/extract/parity untouched), folded into
   the embedded bundle by `gen-reference`. This file is also the intended home for the per-setting
   **descriptions** (the earlier roadmap item), so that follow-up needs no new plumbing.
7. **Unsaved-changes guard** — the edit model tracks a `dirty` flag; quitting the TUI while dirty
   asks for confirmation and reports how long ago the last save was.
8. **Default value highlighted** — in Set setting, the default is shown bold in the label and the
   default option is marked "(default)" in the bool/enum lists.
9. **Fixed file names + auto-load** — Save/Generate no longer prompt for a path (canonical
   `user-config.yaml` / `CTLD_userConfig.lua`); the TUI auto-loads `user-config.yaml` on start if it
   exists. Only Inject prompts (the `.miz`).
10. **Edit a tree entry** (`e`) — reopens the matching form pre-filled with the current values and
    updates the entry in place (via `EditModel.update_entry`), so a mistake (e.g. a crate added
    without a name) can be corrected instead of deleted and re-entered. Covers all six entry kinds.
11. **Weight uniqueness on patch** — a `patch` that changes a crate's weight is validated for
    collision (excluding the target's own current weight), and `gen-user` maps the patch's
    `weight_kg` to the runtime `weight` key. Uniqueness on `add` was already covered (now also
    locked by a test for two same-weight adds).
12. **File browser for inject** — Inject opens a `DirectoryTree` modal filtered to `.miz` files
    (rooted at the user-config's folder) instead of a free-text path prompt. `PathPrompt` removed
    (Save/Generate use fixed names).
