# 05 — Pre-filled modify form (core feature request)

Status: ✅ done
Type: reference + tui + tests

FullGas's central ask: modifying should not require knowing the field names.

- **E1** — the **Modifier** action opens the **full Add form** (`AddCrateForm` /
  `AddTroopForm`), **pre-filled with the entry's current values**, instead of the raw
  `PatchByNameForm` (field-name + value). Generalise to crates, troop groups and
  list-settings (`AppendArrayForm`). The form already supports `initial=` (used by the `e`
  edit path) — route the catalogue Modifier through it.
- **E2** — show the **CTLD default as a hint** per field, distinct from the current value in
  the input: field label carries the default, e.g. `aa  (défaut CTLD : 2)`. Where a field is
  unset, the input is empty and the hint still shows the default.
- **Reference support** — expose full default entries by name:
  - add `troop_by_name` (full `loadableGroups` entry, today only `_troop_names`),
  - extend the crate index to the full `spawnableCrates` entry (today `_crate_by_name` keeps
    only `(weight, section)`).
  Source data is already loaded in `Reference.settings`.
- **Output semantics** — the produced op stays a `patch` (diff vs the default): only fields
  the MM actually changed are written. Confirm the diff is computed against the CTLD default,
  not blindly dumped, to keep `CTLD_userConfig.lua` minimal.

Files: `ctld_tools/reference.py`, `ctld_tools/tui/app.py` (`_form_patch_*`,
`action_edit_entry`), `ctld_tools/tui/forms.py` (default-hint labels),
`ctld_tools/data/locales/{en,fr}.json`. Tests: reference exposes full entries; modify form
pre-fills current values + default hints; the emitted patch contains only changed fields.
</content>
