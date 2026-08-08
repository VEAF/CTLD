Status: ready

# 02 — Show troop count in the "Extract from field" menu

## Parent

`.backlog/FIX-FIELD-EXTRACT-CASUALTIES/PRD.md`

## What to build

Update the "Extract from field" F10 menu (built in `refreshMenuSection`) to show each nearby
dropped group's current logical troop count, using the helper introduced in ticket 01 and the
now-filtered results of `_findNearestDropped` / `_findAllNearbyDropped`:

- Single nearby group (direct button) → `"Extract: %1 (%2 troops)"` (group name, logical count).
- Multiple nearby groups (submenu entries) → `"%1 (%2 troops, %3m)"` (group name, logical count,
  distance in meters, floored as today).

Both strings go through `ctld.tr(...)`, consistent with every other player-facing string in this
file.

Run `merge_CTLD.ps1` (which invokes `generate_i18n_dicts.ps1 -Apply`) to sync the new i18n keys,
and fill in real translations for all four languages (EN/FR/ES/KO) — not empty stubs.

Update `docs/pilot/troop-transport.md` and `docs/pilot/troop-transport.fr.md`, section
"Extracting from the field", which currently documents the distance-only label (`Bravo (25m)`), to
reflect the new format.

## Acceptance criteria

- [ ] With exactly one dropped group in extraction range, the F10 menu shows
      `Extract: <name> (<N> troops)` where `<N>` is the group's current logical count.
- [ ] With two or more dropped groups in extraction range, the "Extract from field" submenu shows
      `<name> (<N> troops, <D>m)` for each entry, sorted by distance as today.
- [ ] A dropped group with 0 logical troops (servant-only residue) never appears in either menu
      form (covered by ticket 01's filtering — verified here at the menu-rendering seam).
- [ ] New i18n keys are present with non-empty translations in all four language dictionaries
      (EN/FR/ES/KO).
- [ ] `docs/pilot/troop-transport.md` and `.fr.md` reflect the new label format in the
      "Extracting from the field" section.
- [ ] `busted tests/ci/` passes clean; `luacheck --config .luacheckrc src/` clean.

## Blocked by

- `01-logical-count-fix-and-filtering.md` (needs the shared logical-count helper and the filtered
  nearby-group lookups).
