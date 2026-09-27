# FIX-LUACHECK-REMAINING-WARNINGS — "Lot B", the last 30 of the 89 `luacheck` warnings

**Status:** 🔄 in review (PR #208).

Formalizes "Lot B" of the `luacheck` warning-cleanup work, following `FIX-LEGACY-API-PARAM-PREFIX`
("Lot A", the 58 `legacy_api.lua` parameters). This closes out the debt `TOOLING-LUACHECK-CI-RATCHET`
quantified: the project-wide `luacheck` warning count reaches **0** for the first time.

## Problem Statement

After Lot A, 31 warnings remained across ~9 files, each needing individual judgment unlike Lot A's
single uniform pattern (see `dev/roadmap.md`'s breakdown at the time). One of the 31 — an empty
`if` branch in `CTLD_vehicle.lua` whose body is entirely comments describing an unimplemented
feature (native-cargo bbox-exit detection) — is **not** a lint problem to fix; deleting it would
silently erase a documented gap. The other 30 are genuine, independent, low-risk cleanups.

## Solution

- The one ambiguous case is handled **separately from this lot**: an inline `-- luacheck: ignore
  542` suppresses the warning at that specific line without touching the code, and a new
  `dev/roadmap.md` entry ("Native-cargo bbox-exit detection is unimplemented") documents the real
  gap the comments describe, so a future contributor can pick it up as an actual feature — not
  something this cleanup silently decided.
- The remaining 30 warnings are fixed directly, one category at a time:
  - **8** instances of the same misleadingly-`_`-prefixed-but-actually-used pattern Lot A fixed at
    scale, here scattered as isolated single/double occurrences: `CTLD_crate.lua` (`_noRefresh`
    ×2, one shared name across two functions), `CTLD_recon.lua` (`_fromScan`), `CTLD_utils.lua`
    (`_point1`/`_point2`, `_points`, `_unitId`, `_table` — renamed to `tbl`, not `table`, to avoid
    shadowing the Lua stdlib).
  - **10** genuinely unused variables, each verified dead (no later read, and the discarded
    right-hand-side expression is a side-effect-free getter/computation) before deletion:
    `CTLD_config.lua` (a module-load-time singleton fetch whose result was never used — verified
    `CTLDConfig.get()` is an idempotent lazy singleton, so removing the early call doesn't change
    *when* it's first constructed in any observable way), `CTLD_troop.lua`, `CTLD_utils.lua` ×3,
    `CTLD_vehicle.lua` ×5 (one function, `packVehicle` — `isDynamic` also removed alongside its
    only consumer `modelKey`, even though `isDynamic` itself wasn't flagged, to avoid trading one
    unused-variable warning for a new one).
  - **5** shadowing/redefinition fixes, each by renaming the shadowing variable (never the
    shadowed one, to keep the diff minimal): `CTLD_beacon.lua` (a UHF frequency-pool loop counter
    reusing `f` after an FM-pool loop already uses `f` later in the same function),
    `CTLD_crate.lua` (a redundant re-derivation of a value already in scope — deleted, not
    renamed), `CTLD_utils.lua` ×3 (two argument-defaulting idioms rewritten to reassign the
    parameter instead of shadowing it with a `local`; one recursive-helper/outer-parameter name
    collision in `deepCopy`, outer renamed `object` → `obj`).
  - **5** lines wrapped under 200 characters — a doc-comment example, an API-signature reference
    comment, a `luacheck`-flagged long condition (extracted into a named local before the `if`,
    also improving readability), an over-padded inline comment, and a `ctld.tr()` call's trailing
    arguments moved to a continuation line (the translated string literal itself is untouched —
    i18n key extraction matches string content, not line position, and this PR does not touch it).
  - **1** simplifiable negation (`CTLD_jtac.lua`): `not (x ~= false)` → `x == false`, safe here
    since the right-hand side is a literal boolean, not a table or NaN-prone number (`luacheck`'s
    own caveat for this rewrite).
  - **1** trivial empty `if` branch (`CTLD_vehicle.lua:1381`, unrelated to the documented-gap case
    above): inverted via De Morgan (`if A and B then <empty> else <logic> end` → `if (not A) or
    (not B) then <logic> end`), preserving exact semantics.
- `LUACHECK_WARNING_CEILING` lowered `31` → `0` in `.github/workflows/ci.yml`, in the same PR.

## User Stories

1. As a developer running `luacheck` (locally or in CI), I want the project to report 0 warnings
   for the first time, so that `CLAUDE.md`'s "must be clean" claim is finally literally true.
2. As a developer maintaining the ratchet, I want `LUACHECK_WARNING_CEILING` at `0`, so that any
   future warning — of any kind — is caught immediately, with no slack left over from this debt.
3. As a developer reading `CTLD_vehicle.lua`'s native-cargo bbox-exit code, I want the documented,
   unimplemented intent behind the empty branch preserved and tracked in `dev/roadmap.md` — not
   silently deleted by a lint cleanup that mistook it for dead code.
4. As a Mission Maker, I want every one of these 30 fixes to change nothing about how CTLD behaves
   in game — they are internal code-quality fixes, verified against the existing `busted` suite and
   a full engine rebuild.

## Implementation Decisions

See Solution above for the categorized list. Cross-cutting decisions:

- **No behavior change anywhere** — every fix is either a pure rename (parameter/local, both
  declaration and every reference within its own scope), a dead-computation deletion (verified
  side-effect-free first), a logically-equivalent condition rewrite (De Morgan, or the documented
  `luacheck` negation-simplification caveat), or pure line-wrapping. None of the 30 touches what
  any function actually computes or returns.
- **The `CTLD_vehicle.lua:734` gap is deliberately out of this lot's fixes** — suppressed via
  `-- luacheck: ignore 542`, not deleted, with a `dev/roadmap.md` entry carrying the intent forward.
  This is the one point in the whole cleanup where "make the warning go away" and "fix the
  underlying thing" are genuinely different actions, and this lot only does the former, on purpose.
- **`isDynamic` removed in `CTLD_vehicle.lua:packVehicle`** even though `luacheck` didn't flag it
  directly — its only consumer (`modelKey`) is one of the 5 flagged-unused locals in that same
  function; leaving `isDynamic` in place after removing `modelKey` would trade one warning for a
  new one (an unused `isDynamic`). Verified its right-hand side (`_isNativeCargoCapable(transport)`)
  is a pure predicate, safe to drop entirely.
- **`_table` renamed to `tbl`, not `table`** (`CTLD_utils.lua:countTableEntries`) — `table` is the
  Lua 5.1 stdlib namespace, already a `read_global` in `.luacheckrc`; naming a local parameter
  exactly `table` would shadow it, trading one warning for another this lot exists to avoid
  introducing.
- **No `.luacheckrc` changes** — every one of the 30 fixes is real code, not a new exemption; the
  single deliberate exemption (`CTLD_vehicle.lua:734`) uses `luacheck`'s own inline directive
  (`-- luacheck: ignore 542`), scoped to that one line, not a project-wide config change.

## Testing Decisions

- No new tests — every fix is a pure rename, a verified-dead-code deletion, or a logically
  equivalent rewrite; nothing here is new behavior to cover.
- Regression proof: full `busted tests/ci/` run (1472 passed, 0 failed, 1 pending — the same
  pre-existing live-DCS-only pending spec, unrelated) plus a full `CTLD.lua` rebuild +
  `luac5.1 -p` syntax check, both unchanged from before this lot.
- `luacheck --config .luacheckrc src` — 0 warnings, 0 errors, 33 files (down from 31; the
  `CTLD_vehicle.lua:734` case is suppressed inline, accounted for separately, not "fixed").

## Out of Scope

- `CTLD_vehicle.lua:734`'s actual native-cargo bbox-exit detection — a real feature gap, now
  tracked in `dev/roadmap.md`, not built here.
- Any other pre-existing code-quality observation not flagged by the current `.luacheckrc`
  ruleset (e.g. the ~150-line dead `CTLDPlayerTracker` class mentioned in prior lots' history,
  or the possible dead first `ctld.utils.getGroupId` definition noticed in passing while fixing
  `CTLD_utils.lua`'s `_unitId` — a second definition of the same function exists later in the same
  file and silently wins at load time; not investigated further, out of scope for a lint-warning
  cleanup, worth its own look if confirmed).

## Further Notes

No ADR — mechanical/low-risk fixes plus one documented, deliberate exemption, not a design
decision. `dev/roadmap.md` gains one new entry (the bbox-exit gap) and loses the "Lot B" debt
breakdown note (superseded by this lot's completion).
