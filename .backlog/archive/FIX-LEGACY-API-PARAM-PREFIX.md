# FIX-LEGACY-API-PARAM-PREFIX

**Status:** merged (PR #206). Compacted from `FIX-LEGACY-API-PARAM-PREFIX/` on 2026-10-09; the ticket files live on in git history.

"Lot A" of the luacheck warning cleanup (`TOOLING-LUACHECK-CI-RATCHET`'s debt): all 58 parameters in `src/legacy/legacy_api.lua` shared the codebase's "deliberately unused" `_` prefix convention while actually being used (forwarded verbatim to the v2 manager call) — the convention itself was misleading, not the code. Pure rename (signature + body, both places a name appears), one exception (`_coalition` → `coalitionId`, avoiding a DCS global shadow). `LUACHECK_WARNING_CEILING` lowered 89 → 31 in the same PR. "Lot B" (the remaining 31, ~9 files, individual judgment per warning) stays a separate future lot.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-drop-underscore-prefix` | ✅ done | 01 — Drop the `_` prefix from every parameter in `legacy_api.lua`, lower the ratchet ceiling |

## PRD

## FIX-LEGACY-API-PARAM-PREFIX — drop the misleading `_` prefix in `legacy_api.lua`

**Status:** ✅ done (PR #206).

Formalizes "Lot A" of the luacheck warning-cleanup work identified in `dev/roadmap.md`'s (now
closed) "luacheck n'est en réalité vérifié nulle part" entry and `TOOLING-LUACHECK-CI-RATCHET`'s
own quantified debt breakdown: 58 of the 89 pre-existing warnings were every parameter in
`src/legacy/legacy_api.lua`, all sharing one misleading pattern.

### Problem Statement

Every function in `src/legacy/legacy_api.lua` (the v1→v2 compatibility wrapper layer) names its
parameters with a leading `_` — the codebase's convention for "deliberately unused" (e.g.
`_isServantUnitName`, DCS callback args). But every one of these parameters **is** used: each
wrapper forwards its arguments verbatim to the corresponding v2 manager call. `luacheck` correctly
flags all 58 of them ("used variable '_xxx' with unused hint") — the convention itself lies about
the parameter's role, not the surrounding code.

### Solution

Drop the leading `_` from every parameter in every function in this file, in both the signature and
the body reference. Pure rename, no behavior change: Lua has no named-argument call syntax, so
nothing outside this file's own body can observe a parameter's name — every caller (legacy mission
`DO SCRIPT` triggers, calling `ctld.spawnGroupAtTrigger(a, b, c, d)` positionally) is unaffected.

One parameter is renamed to something other than the literal de-prefixed name:
`createRadioBeaconAtZone`'s `_coalition` becomes `coalitionId`, not `coalition` — `coalition` is
already a DCS global namespace table (`.luacheckrc`'s `read_globals`), and a local parameter with
that exact name would shadow it, trading one warning for another.

### User Stories

1. As a developer reading `legacy_api.lua`, I want a parameter's name to honestly reflect whether
   it's used, so that the `_`-prefix convention means the same thing here as everywhere else in
   `src/`.
2. As a developer running `luacheck` (locally or in CI), I want this file to report 0 warnings, so
   that the 58 entries it used to contribute to the debt are gone for good, not suppressed.
3. As a Mission Maker whose mission calls a legacy `ctld.*` wrapper function from a `DO SCRIPT`
   trigger, I want every call to keep working identically, so that this internal renaming never
   reaches me — Lua's positional-only call convention guarantees this, but it's worth stating as
   the thing this lot must never break.
4. As a developer maintaining `TOOLING-LUACHECK-CI-RATCHET`'s ratchet, I want
   `LUACHECK_WARNING_CEILING` lowered to match the new real total once this lot's fix lands, so the
   ratchet actually tightens instead of leaving 58 warnings' worth of slack sitting unused.

### Implementation Decisions

- **Every one of the 22 functions in `src/legacy/legacy_api.lua` is rewritten**: parameter names
  lose their `_` prefix in both the `function ctld.xxx(...)` signature and the forwarding call
  inside the body — the file's only two places each name appears.
- **No behavior change of any kind** — no logic, no log message text, no call order, no added or
  removed parameters. Verified: `busted tests/ci/` (1472 passed, 0 failed, 1 pre-existing pending)
  and a full `CTLD.lua` rebuild + `luac5.1 -p` syntax check both pass unchanged.
- **`_coalition` → `coalitionId`** (not `coalition`) in `createRadioBeaconAtZone` — the one
  exception to a literal de-prefix, to avoid shadowing the DCS `coalition` global.
- **`LUACHECK_WARNING_CEILING` lowered from `89` to `31`** in `.github/workflows/ci.yml` (the new
  real total, reverified: `Total: 31 warnings / 0 errors in 33 files`) — the ratchet tightens in
  the same PR that earns the reduction, not left for a separate follow-up.
- **No new test file.** `tests/ci/unit/legacy_api_spec.lua` already exercises these wrappers by
  calling them positionally (exactly how a real mission trigger would); it needed no changes and
  its continued pass is the regression proof.

### Testing Decisions

- Regression proof is the existing `tests/ci/unit/legacy_api_spec.lua` (unchanged) plus the full
  `busted tests/ci/` run — a pure rename has nothing new to test, only existing behavior to not
  break.
- `luacheck --config .luacheckrc src/legacy/legacy_api.lua` — 0 warnings, confirms the fix.
- `luacheck --config .luacheckrc src` — confirms the project-wide total dropped from 89 to 31,
  grounding the ratchet-ceiling change.

### Out of Scope

- The remaining 31 warnings across ~9 other files (unused variables, shadowing, empty `if`
  branches, a simplifiable negation, long lines) — "Lot B" of the same cleanup, a separate future
  lot, each warning needing individual judgment unlike this file's single uniform pattern.
- Any change to what `legacy_api.lua` actually does, or to its deprecation-warning strategy.

### Further Notes

No ADR — a mechanical rename fixing a misleading local convention, not a design decision.
