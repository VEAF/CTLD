# 01 — Fix the remaining 30 warnings, suppress the 1 documented gap, ratchet to 0

**Status:** ✅ done

**Blocked by:** none.

## What to build

Per the PRD's categorized list: 8 `_`-prefix renames, 10 unused-variable deletions (verified
side-effect-free), 5 shadowing/redefinition fixes, 5 line-wraps, 1 negation simplification, 1
trivial empty-if inversion — across `CTLD_beacon.lua`, `CTLD_config.lua`, `CTLD_crate.lua`,
`CTLD_jtac.lua`, `CTLD_recon.lua`, `CTLD_troop.lua`, `CTLD_utils.lua`, `CTLD_vehicle.lua`,
`CTLD_zone.lua`. Separately, `CTLD_vehicle.lua:734`'s empty if branch (the unimplemented
native-cargo bbox-exit detection) gets `-- luacheck: ignore 542` plus a new `dev/roadmap.md` entry
documenting the gap — not deleted. Lower `LUACHECK_WARNING_CEILING` from `31` to `0`.

## Watch out

- Every rename must cover both the declaration and every reference within its own function scope
  — grep before and after each change to confirm no site was missed and no new collision
  introduced.
- Before deleting any "unused variable," confirm its right-hand-side expression has no side
  effects (a plain field/getter read is safe; anything that logs, mutates state, or spawns/destroys
  something is not deletable without changing behavior).
- `_table` → `tbl`, never `table` (Lua stdlib global, already a `.luacheckrc` `read_global`).
- Do not touch the translated string literal in the `CTLD_zone.lua` `ctld.tr()` fix — only move the
  trailing arguments to a continuation line; i18n key extraction matches string content.
- `CTLD_vehicle.lua:734` is explicitly NOT part of the 30 — suppress inline, document in the
  roadmap, do not delete the comments describing the unimplemented behavior.

## Acceptance

- `luacheck --config .luacheckrc src` → 0 warnings, 0 errors, 33 files.
- `busted tests/ci/` unchanged pass count (regression-free).
- `CTLD.lua` rebuilds and passes `luac5.1 -p`.
- `LUACHECK_WARNING_CEILING` is `0` in `ci.yml`.
- `CTLD_vehicle.lua:734` carries `-- luacheck: ignore 542` and is otherwise untouched; a new
  `dev/roadmap.md` entry describes the gap.

## Tests

None new — every fix is a pure rename, a verified-dead-code deletion, or a logically equivalent
rewrite. `busted tests/ci/` is the regression proof.

## Verification log

- `luacheck --config .luacheckrc src`: `Total: 0 warnings / 0 errors in 33 files` (was 31, minus 1
  suppressed inline).
- `busted tests/ci/`: `1472 successes / 0 failures / 0 errors / 1 pending` (pre-existing, needs
  live DCS) — unchanged.
- `merge_CTLD.ps1` rebuild + `luac5.1 -p CTLD.lua`: syntax OK.
