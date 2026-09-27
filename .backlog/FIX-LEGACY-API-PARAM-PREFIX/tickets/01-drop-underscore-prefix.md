# 01 — Drop the `_` prefix from every parameter in `legacy_api.lua`, lower the ratchet ceiling

**Status:** ✅ done

**Blocked by:** none.

## What to build

Rewrite every function signature and body in `src/legacy/legacy_api.lua`, dropping the leading `_`
from each parameter name (22 functions, 58 parameters total). Lower
`.github/workflows/ci.yml`'s `LUACHECK_WARNING_CEILING` from `89` to `31`.

## Watch out

- `_coalition` → `coalitionId`, not `coalition` — `coalition` is a DCS global (`.luacheckrc`
  `read_globals`); a local param of that exact name would shadow it.
- Pure rename only — no logic, log text, or call-order change anywhere in this file.
- Update the ratchet ceiling in the same PR — don't leave it at a stale, slacker value.

## Acceptance

- `luacheck --config .luacheckrc src/legacy/legacy_api.lua` → 0 warnings.
- `luacheck --config .luacheckrc src` → 31 warnings, 0 errors, 33 files (down from 89).
- `busted tests/ci/` unchanged pass count (regression-free).
- `CTLD.lua` rebuilds and passes `luac5.1 -p`.
- `LUACHECK_WARNING_CEILING` is `31` in `ci.yml`.

## Tests

None new — `tests/ci/unit/legacy_api_spec.lua` (pre-existing, unchanged) plus the full `busted
tests/ci/` run are the regression proof for a pure rename.

## Verification log

- `luacheck` on the file alone: `Total: 0 warnings / 0 errors in 1 file`.
- `busted tests/ci/`: `1472 successes / 0 failures / 0 errors / 1 pending` (the one pending spec
  needs live DCS, pre-existing and unrelated).
- Project-wide `luacheck`: `Total: 31 warnings / 0 errors in 33 files` (was 89).
- `merge_CTLD.ps1` rebuild + `luac5.1 -p CTLD.lua`: syntax OK.
