# 03 — Guards & dedup (core bug fix)

Status: ✅ done
Type: editmodel + tui + tests

Root-cause fix for FullGas's 2nd/3rd-line repro. Two layers: prevention upstream,
block+message as the safety net.

## Model layer (`editmodel.py`)

- **C1** — `remove_crate` / `remove_troop`: reject a target already present in the
  respective `remove` bucket (no-op, signalled to the caller).
- **C2** — `patch_crate` / `patch_troop`: reject a target already present in the `patch`
  bucket — **block, do not reroute** to editing the existing entry (David's call). Signalled
  to the caller.
- **C3** — reject an empty/invalid op: a patch with no field (already guarded in the form,
  enforce in the model too) and a remove of a name absent from the catalogue → surfaced as a
  finding/return, not a silent append.
- The signalling: return a bool (or raise a small typed result) so the app can notify;
  keep `_checkpoint`/`revalidate` semantics intact (no checkpoint on a rejected op).

## UI layer (`tui/app.py`, `tui/forms.py`)

- **B3 (extended) — prevention upstream:** the Retirer / Modifier pickers grey out (or omit)
  names already consumed in the diff, so a duplicate is unreachable. `PickerModal` /
  `PatchByNameForm` accept a `disabled`/`used` set; `FilterablePicker` renders those entries
  non-selectable.
- On a rejected op (safety net), `notify(...)` the reason and select the existing line in the
  tree (ties in with ticket 04).

Tests (`tests/` for ctld-tools): dedup rejection for remove and patch (crate + troop), empty
patch rejected, absent-name remove flagged, picker excludes consumed names. This ticket is
the one that must reproduce-then-fix FullGas's scenario in a unit test.
</content>
