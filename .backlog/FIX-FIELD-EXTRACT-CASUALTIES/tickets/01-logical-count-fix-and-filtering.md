Status: ready

# 01 — Logical count fix: field extraction reflects survivors

## Parent

`.backlog/FIX-FIELD-EXTRACT-CASUALTIES/PRD.md`

## What to build

Factor the existing servant-exclusion rule (already implemented in
`CTLDTroopGroup:_syncFromDCSGroup` — count a live DCS group's units, excluding any named with the
`SVNT` prefix) into a helper that can be applied against any live DCS `Group` object.

Use this helper in `embarkFromField` to compute the extracted logical troop count from the DCS
group's **currently alive** units, replacing the current logic that prefers `stored.total` (the
headcount frozen at deploy time). `stored.total` / `stored.weight` stay in `_droppedTemplates`, but
are now used only to derive the original per-unit average weight
(`stored.weight / stored.total`), which still multiplies against the new, correct logical count to
produce proportional cargo weight.

Apply the same helper in `_findNearestDropped` and `_findAllNearbyDropped` to exclude any dropped
group whose live logical count is 0 (a group where every real troop-role unit has died, leaving
only a `SVNT_*` mortar servant standing) — such a group is no longer a valid extraction candidate
at either lookup site.

Add the `CHANGELOG.md` `[Unreleased]` entry for this fix.

## Acceptance criteria

- [ ] A shared helper counts a live DCS group's alive units excluding any named with the `SVNT`
      prefix, and is used by `embarkFromField`, `_findNearestDropped`, and
      `_findAllNearbyDropped`.
- [ ] `embarkFromField` on a group that lost units since deployment (mocked `getUnits()` returning
      fewer live units than `stored.total`, including one `SVNT_`-prefixed mock unit among the
      survivors) extracts the correct survivor count, excluding the servant — not `stored.total`.
- [ ] `embarkFromField` on a group with zero casualties still extracts the full original count (no
      regression on the common, undamaged case).
- [ ] Cargo weight after extraction is proportional to the corrected survivor count (unchanged
      `avgWeight * logicalCount` formula, fed the corrected count).
- [ ] `_findNearestDropped` and `_findAllNearbyDropped` never return a dropped group whose live
      logical count is 0.
- [ ] The mortar unit itself (role `mortar`, not prefixed `SVNT`) is always included in the logical
      count — only its cosmetic servant is excluded.
- [ ] A group carrying a JTAC extracts with the same logical count as before this change (no
      regression).
- [ ] `CHANGELOG.md` has a new `[Unreleased]` entry describing the fix.
- [ ] `busted tests/ci/` passes clean; `luacheck --config .luacheckrc src/` clean.

## Blocked by

None — can start immediately.
