# 02 — Scalars editor: full end-to-end

Status: ready

## What to build

Deliver the first fully working vertical slice of the v2 editor: scalar settings
(mm_facing + advanced) browsable in the catalogue tree, editable in the form panel, with
the footer operational (Save / Generate / Inject) and all cross-cutting concerns wired
(validation, undo/redo, 4 visual states, i18n).

After this slice the tool is **demoable on its own**: a MM can open ctld-tools, browse
all scalar parameters, click one (e.g. `numberOfTroops`), see its current/default value
in the form, change it, Apply, Save, Generate — and get a valid `CTLD_userConfig.lua`.
Tree and footer work for the entire lifetime of the app from this point forward; later
slices only add new sections.

End-to-end behaviour:
- Tree shows "Parameters → Standard" and "Parameters → Advanced" collapsed at startup.
- Expanding a section lists all scalar keys; clicking a key opens the form with the
  current effective value pre-filled (default if not overridden, MM's value if set).
- Entries overridden by the MM appear bold with `*`; unmodified entries appear normal.
  (No add/delete states for scalars — Type A.)
- Form: labelled field, Apply commits to `EditModel`, Cancel discards. No Delete button.
- Inline validation error appears under the field when the value is invalid.
- Footer: validation summary label (left), Save / Generate / Inject buttons (right).
  Generate is disabled and its tooltip shows the error count when `not model.can_generate`.
- Ctrl+Z / Ctrl+Y undo/redo tree + form.
- Save writes `user-config.yaml`; Generate compiles `CTLD_userConfig.lua`; Inject opens
  a `.miz` file picker and calls the existing inject logic.
- Interface language follows OS locale or `--lang` flag.

## Acceptance criteria

- [ ] Tree renders "Parameters / Standard" and "Parameters / Advanced" as collapsible
  first-level nodes; expanding shows all scalar keys from `Reference.scalar_settings()`.
- [ ] Scalars overridden in an existing `user-config.yaml` appear bold + `*` in the tree
  on startup; unmodified scalars appear in normal style.
- [ ] Clicking a scalar key populates the form with the current effective value
  (default from `Reference` if not overridden; MM value if set).
- [ ] For bool/enum scalars, the form uses a dropdown (as in v1); for free-text scalars,
  a text input. Field label tooltip shows the description from `CTLD_config_schema.yaml`
  (existing scalar descriptions; no new descriptions required in this slice).
- [ ] Apply commits the change to `EditModel`; the tree entry immediately updates to
  bold + `*`. Cancel discards without changing the model.
- [ ] No Delete button appears for scalar entries.
- [ ] Validation error for an invalid scalar value appears inline under the field.
- [ ] Footer validation label updates on every `EditModel` mutation.
- [ ] Generate button is disabled while `not model.can_generate`; tooltip states error count.
- [ ] Save, Generate, Inject work end-to-end (same contracts as v1).
- [ ] Ctrl+Z / Ctrl+Y undo/redo; tree + form reflect the rolled-back state.
- [ ] `test_catalogue_tree.py` created: asserts scalar tree rows carry the correct tag
  (`default` / `modified`) given a known `EditModel.config`.
- [ ] `test_forms.py` rewritten: asserts Apply commits to model; Cancel does not; Delete
  absent for scalars.

## Blocked by

- Ticket 01 (foundation shell)
