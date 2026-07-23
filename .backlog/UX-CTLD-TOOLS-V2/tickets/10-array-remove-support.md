# 10 — Name/Role Lists — remove default entries

Status: ready

## What to build

Allow the MM to suppress default entries from `transportPilotNames`, `extractableGroups`
and `logisticUnits` — the "Name / Role Lists" tree section. Currently only append is
supported (`ctld.addTo`). This slice adds end-to-end remove support across five layers:
Lua runtime, config format, EditModel, genuser, and the tree UI.

### Config format

A new top-level key `arrayRemovals` stores names to suppress. The existing `arrays` key
(appends) is unchanged — fully backwards-compatible.

```yaml
arrays:
  transportPilotNames:
    - "helicargo_custom_1"      # unchanged: appended to default list

arrayRemovals:
  transportPilotNames:
    - "helicargo01"             # new: suppressed from the default list
```

### CTLD runtime

Add `ctld.removeFrom(settingName, value)` to `src/CTLD_userSetup.lua`. It removes the
first matching entry from the named array setting. This is the only `src/` change.
`CHANGELOG.md [Unreleased]` must be updated.

### EditModel

- `remove_from_list(setting, name)` — appends `name` to `config.arrayRemovals[setting]`
  and calls `_checkpoint()`.
- `restore_list_entry(setting, name)` — removes `name` from `config.arrayRemovals[setting]`
  and calls `_checkpoint()`.

### genuser.py

Before the existing `ctld.addTo` loop, emit `ctld.removeFrom` calls for each entry in
`arrayRemovals`.

### Tree UI

- Default list entries (`mlist_default:*`): show a `Delete` button in the read view.
  Clicking it calls `remove_from_list()` and rebuilds the tree → entry turns
  `deleted` (strikethrough + grey).
- Deleted default entries: clicking them shows `Restore` instead of `Delete`.
- User-added entries (`mlist_add:*`): behaviour unchanged.

## Acceptance criteria

- [ ] `ctld.removeFrom(settingName, value)` is implemented in `src/CTLD_userSetup.lua`
  and removes the first matching entry from the target array setting.
- [ ] `CHANGELOG.md [Unreleased]` has an entry for the new helper.
- [ ] `EditModel.remove_from_list()` and `restore_list_entry()` are implemented and
  undo/redo-able.
- [ ] `genuser.py` emits `ctld.removeFrom()` calls for all `arrayRemovals` entries,
  before `ctld.addTo()` calls.
- [ ] Clicking `Delete` on a default list entry marks it as deleted in the tree
  (strikethrough + grey) and persists to `arrayRemovals` in the config.
- [ ] Clicking a deleted entry shows `Restore`; clicking `Restore` removes the entry
  from `arrayRemovals` and restores it to `default` state in the tree.
- [ ] Undo/Redo works for remove and restore operations.
- [ ] A `user-config.yaml` with `arrayRemovals` round-trips correctly through Save →
  reload → Generate → `CTLD_userConfig.lua` contains the `ctld.removeFrom()` calls.
- [ ] New tests: `test_editmodel.py` (remove/restore), `test_genuser.py` (removeFrom
  emission), `test_catalogue_tree.py` (deleted state for mlist entries).
- [ ] Existing 272 tests still pass.

## Blocked by

- Ticket 07 (mission lists tree — already merged on branch)
