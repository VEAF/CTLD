Status: ⬜ ready

# 02 — Add (xN) crate-count suffix to all Request Equipment labels

## What to build

Append `" (xN)"` to the `desc` of every `singleCrate` entry in "Request Equipment",
where N is `cratesRequired` (defaulting to 1). The suffix is applied at the point
where `desc` is constructed from the i18n key — after `ctld.tr()` — in both code
paths that build singleCrate entries:

- Scene injection path (`_injectSceneCrate`)
- YAML catalogue path (`_processSpawnableCrates`)

The suffix is unconditional: `cratesRequired = 1` produces `(x1)`, ensuring total
consistency across all entries. `mixedSet` entries (AA "All crates" from YAML) are
not modified — they have explicit labels.

Because `singleTypeSet.desc` is derived from `entry.desc` after the suffix is
applied, it will read e.g. `"FOB Crate (x3) - All crates"`. This is accepted.

## Acceptance criteria

- [ ] Every entry in "Request Equipment" shows `(xN)` as a suffix, where N matches
      `cratesRequired` for that entry
- [ ] `cratesRequired = 1` entries show `(x1)` (unconditional)
- [ ] The suffix is ASCII `(xN)`, no Unicode characters
- [ ] The suffix is appended after the translated label, not baked into i18n keys
- [ ] `mixedSet` entries (AA "All crates") are unaffected
- [ ] New busted L1 tests:
  - `_processSpawnableCrates`: entry with `cratesRequired = 1` → `desc` ends with `" (x1)"`
  - `_processSpawnableCrates`: entry with `cratesRequired = 3` → `desc` ends with `" (x3)"`
  - `_injectSceneCrate`: scene crate with `cratesRequired = 1` → `desc` ends with `" (x1)"`
  - `_injectSceneCrate`: scene crate with `cratesRequired = 3` → `desc` ends with `" (x3)"`
- [ ] All existing `tests/ci/` pass (including any that assert on `desc` values — update if needed)
- [ ] `CTLD.lua` rebuilt via `merge_CTLD.ps1`

## Blocked by

None — can start immediately.
