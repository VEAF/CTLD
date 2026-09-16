# 01 — Destroy real ground crates found for a `NoCrate` part during assembly

**Status:** ✅ done

Implemented at `tests/ci/unit/aasystem_spec.lua` (not `CTLD_aasystem_spec.lua` — corrected the
filename this ticket originally assumed) with 6 new cases: the 5 planned below, plus an explicit
regression guard confirming the fix doesn't change *which* over-supplied non-`NoCrate` crate
survives (unordered by design, only the count is guaranteed). `busted tests/ci/` green
(1370/1370), `luacheck` clean, `CTLD.lua` rebuilds and loads under Lua 5.1.

See the PRD for the full trace of why `Hawk pcp`/`Hawk cwar`/`Patriot AMG` crates never get
cleaned up today.

## What changes

`src/CTLD_aasystem.lua`, `CTLDCrateAssemblyManager:_assemble()`, the "Destroy consumed crates"
loop (around the `for _, part in ipairs(template.parts) do` block that currently reads
`if not sp.NoCrate then ... end`):

- Split the per-part destroy logic in two:
  - **Non-`NoCrate`** (unchanged): keep the existing `amountFactor = stacking and (sp.found -
    sp.found % sp.required) or 1`, `toDelete = amountFactor * sp.required`, destroy up to
    `toDelete` crates from `sp.crates`.
  - **`NoCrate`** (new): if `sp.crates` is non-empty (a real ground crate was found during
    collection), destroy **all** of them via `cm:destroyCrate(c.crateName)` — no `amountFactor`,
    no `toDelete` cap. If `sp.crates` is empty, do nothing (today's behavior for the common case
    where no real crate exists).
- No change to the collection loop, to `sp.found`/`sp.required` computation, to the completeness
  check, or to anything about how `NoCrate` parts are counted for `count`/`countComplete` — only
  the destruction step changes.
- `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- Don't touch the completeness check (`missingTxt` loop) — `NoCrate` parts must keep satisfying
  `found >= required` unconditionally regardless of whether a real crate exists, exactly as today.
- Don't change anything about `_rearm()`/`_repair()` — they are out of scope for this lot (see
  PRD), and they don't share this destroy loop anyway (each has its own, separate code path).
- `cm:destroyCrate(c.crateName)` already publishes `OnCrateCleared` (confirmed by
  `FIX-AASYSTEM-UNPACK-BUGS`) — no need to publish anything extra here, reuse it exactly as the
  non-`NoCrate` branch already does.

## Acceptance

- [x] A `NoCrate` part (`Hawk pcp`) with one real matching ground crate present: after
  `_assemble()` succeeds, that crate no longer exists in `CTLDCrateManager.crates`.
- [x] Same with **two** real crates present for the same `NoCrate` part: both are destroyed, not
  just one.
- [x] A `NoCrate` part with no real ground crate present: assembly succeeds exactly as today,
  nothing destroyed for that part, no error, no behavior change.
- [x] A non-`NoCrate` part with more crates present than `cratesRequired` and
  `AASystemCrateStacking = false`: destruction is still capped at `required` — proves the fix is
  scoped to `NoCrate` parts only.
- [x] The same holds for Patriot AMG (`Patriot ln`/`Patriot str`/`Patriot ECS` assembly with a real
  `Patriot AMG` crate present).
- [x] `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

`tests/ci/unit/CTLD_aasystem_spec.lua` (extend, don't create a new file — this is the existing
seam `FIX-AASYSTEM-UNPACK-BUGS` already used for `_assemble()`'s `OnCrateCleared` behavior).

Cases, mocking the crate registry the way the existing spec already does:

1. HAWK assembly with launcher + both radars + one real `Hawk pcp` crate nearby → after
   `_assemble()`, assert the `Hawk pcp` crate is gone from the registry and `destroyCrate`/
   `OnCrateCleared` fired for it.
2. Same, with two `Hawk pcp` crates nearby → both gone.
3. HAWK assembly with launcher + both radars, no `Hawk pcp`/`Hawk cwar` crates nearby → assembly
   still succeeds (system spawns), registry unchanged for those part types (nothing to destroy,
   no error).
4. A non-`NoCrate` part (e.g. `Hawk sr`, `cratesRequired = 1`) with 2 crates nearby and
   `AASystemCrateStacking = false` → only 1 destroyed, 1 remains — regression guard for the
   unchanged branch.
5. Patriot assembly with a real `Patriot AMG` crate nearby → destroyed, mirroring case 1 for a
   second template (proves the fix is generic, not HAWK-specific).

No live DCS scenario for this ticket — see the PRD's "Testing decisions" for why.
