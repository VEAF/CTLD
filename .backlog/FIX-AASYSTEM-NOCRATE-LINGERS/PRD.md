# FIX-AASYSTEM-NOCRATE-LINGERS — a real `NoCrate` part crate is never consumed by assembly

**Status:** ⬜ ready

Reported by **a.lingo**, 2026-09-16: after loading the HAWK crate set, transporting it,
dropping it, and successfully unpacking (assembling) the system, the F10 "Unpack Crate" menu
kept showing crate entries as still available, even though the system was already built. Found
by reading the code (no live reproduction attempted for this one — see "Testing decisions").

## The deviation

Two HAWK template parts, `Hawk pcp` and `Hawk cwar`
([CTLD_aasystem.lua:79-80](../../src/CTLD_aasystem.lua#L79)), are marked `NoCrate = true`
("always present at assembly, not a standalone crate") but **also carry a `weight`** — and per
`docs/developer/subsystems/aa.md:65-66`, that combination is deliberate: *"`NoCrate` parts with a
weight still get a menu entry"*. Confirmed in `src/CTLD_config.yaml:535-543`: `Hawk pcp` and
`Hawk cwar` are ordinary `spawnableCrates` entries, individually loadable/droppable through the
normal Request Equipment menu, just excluded from the "HAWK - All crates" convenience bundle
([:545-550](../../src/CTLD_config.yaml#L545)). Same pattern confirmed for `Patriot AMG`
([CTLD_aasystem.lua:132](../../src/CTLD_aasystem.lua#L132),
[CTLD_config.yaml:644-646](../../src/CTLD_config.yaml#L644)). Checked every other `NoCrate` part
across all six AA templates: only these two systems are affected — S-300's `NoCrate` part
("TEL D", [:144](../../src/CTLD_aasystem.lua#L144)) has no `weight` and no corresponding YAML
entry, so it can never physically exist as a ground crate.

So a mission maker's design intent is real: a HAWK PCP/CWAR (or Patriot AMG) crate can genuinely
be picked up and dropped by a player, on purpose or by mistake — grabbing a HAWK PCP crate is
possible, whether from confusion (it looks like any other required part in the menu list) or
deliberate mission-maker staging. **Removing these YAML entries is out of scope** — see below.

`CTLDCrateAssemblyManager:_assemble()` ([CTLD_aasystem.lua:408](../../src/CTLD_aasystem.lua#L408))
has an internal inconsistency, not a design mistake at the catalogue level:

- The **collection** loop (`for _, c in pairs(allCrates) do ...`,
  [:432-450](../../src/CTLD_aasystem.lua#L432)) does not distinguish `NoCrate` parts — if a real
  ground crate matching `Hawk pcp`/`Hawk cwar`/`Patriot AMG` exists nearby, it is found, counted
  into `sp.found`, and appended to `sp.crates`, exactly like any other part's crate.
- The **destruction** loop (`for _, part in ipairs(template.parts) do ...`,
  [:492-506](../../src/CTLD_aasystem.lua#L492)) explicitly skips every `NoCrate` part
  (`if not sp.NoCrate then ... cm:destroyCrate(c.crateName) end`) — so a real crate the collection
  loop just found and counted as consumed is never actually destroyed.

Net effect: the real crate stays registered in `CTLDCrateManager.crates` and `on ground`
indefinitely. `refreshUnpackSection` ([CTLD_crate.lua:691](../../src/CTLD_crate.lua#L691)) keeps
listing it as a complete, assembleable set forever — clicking it re-enters `_assemble()`, which
either hits the coalition system limit or fails with "Cannot build … Missing …" (the other parts
are already gone), never destroying the stray crate either way. A permanently stuck,
permanently-failing menu entry.

## The fix

In `_assemble()`'s destruction loop, drop the `if not sp.NoCrate` guard for the purpose of
destroying crates that were actually found on the ground — but not for the `amountFactor`
("how many crates to consume") arithmetic, which assumes a real per-system crate requirement that
does not apply to a part that is already unconditionally satisfied:

- **Non-`NoCrate` parts** (unchanged): `amountFactor = stacking and (found - found % required) or 1`,
  destroy `amountFactor * required` crates from `sp.crates`.
- **`NoCrate` parts with real ground crates found** (new): destroy **every** crate in `sp.crates`,
  regardless of `stacking`/`required` — there is no meaningful "one system's worth" boundary for a
  part that was never required to have a crate at all; any real crate found for it was either
  mistakenly or deliberately supplied and should be fully consumed once the system it belongs to
  is built.
- **`NoCrate` parts with no real ground crate** (unchanged): nothing to destroy, `sp.crates` is
  empty.

This is one change, generic at the `_assemble()` level — it fixes HAWK (PCP, CWAR) and Patriot
(AMG) identically, with no per-template special-casing.

## Definition of done

- Assembling a HAWK system with a real `Hawk pcp` and/or `Hawk cwar` crate present nearby destroys
  those crates too, alongside the launcher/radar crates — none remain registered afterward.
- Assembling a HAWK system with **no** real PCP/CWAR crate present behaves exactly as today
  (nothing to destroy, no regression).
- The same holds for Patriot AMG.
- Non-`NoCrate` parts' destruction count (the `amountFactor`/stacking arithmetic) is unchanged —
  no regression on the existing "leave leftover crates for a second assembly" behavior when a
  player over-supplies a real part.
- `refreshUnpackSection`'s output after a successful assembly with a real `NoCrate` crate present
  no longer lists that consumed crate — verified via the busted seam described below (no live
  DCS run needed to observe this, the registry state is what the menu builder reads).
- `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.
- `CHANGELOG.md` **Fixed** entry.

## Testing decisions

A good test here asserts on the observable registry/destruction outcome, not on internal call
order — same seam the existing AA assembly spec already uses.

- Prior art: `tests/ci/unit/CTLD_aasystem_spec.lua` (extended by `FIX-AASYSTEM-UNPACK-BUGS` for the
  `OnCrateCleared` publish behavior) — add cases to the same file rather than a new one.
- Cases: (a) a `NoCrate` part (`Hawk pcp`) with one real matching ground crate present — after
  `_assemble()`, that crate is destroyed (`CTLDCrateManager.crates` no longer contains it, and
  `destroyCrate`/`OnCrateCleared` was invoked for it); (b) same with **two** real crates present —
  both destroyed, not just one (the specific edge case the `amountFactor` formula would have
  gotten wrong); (c) a `NoCrate` part with **no** real crate present — assembly succeeds as today,
  nothing destroyed for that part, no error; (d) a non-`NoCrate` part with more crates present than
  `cratesRequired` and `AASystemCrateStacking = false` — destruction count is still limited to
  `required`, proving the fix didn't change behavior for the parts it wasn't meant to touch.
- **No live DCS scenario for this lot.** The mechanism is pure server-side registry logic with no
  DCS-menu-timing dimension (unlike `FIX-MENU-AMBIENT-REFRESH-RACE`) — a live reproduction would
  require assembling a full HAWK system near a player unit, and the risk of a repeat of the
  incident that destroyed the reporting session's C-130 (heavy statics spawned too close to a live
  player unit) outweighs the value here. If a live check is ever wanted, spawn crates 50m+ from any
  player unit — see the session's own recorded lesson on this.

## Out of scope

- Removing the `spawnableCrates` catalogue entries for `Hawk pcp`/`Hawk cwar`/`Patriot AMG`.
  Rejected: `docs/developer/subsystems/aa.md` documents standalone menu entries for weighted
  `NoCrate` parts as deliberate, and no other constraint here explains why — better to make the
  existing, intended crate lifecycle consistent than to remove a documented capability without
  understanding what depends on it.
- `CTLDCrateAssemblyManager._rearm()`/`_repair()` ([:550](../../src/CTLD_aasystem.lua#L550),
  [:620](../../src/CTLD_aasystem.lua#L620)) calling `crate:destroy()` directly instead of
  `CTLDCrateManager:destroyCrate()`, so no `OnCrateCleared` is published and the unpack menu isn't
  refreshed after a rearm/repair. Confirmed present, but a separate, adjacent defect —
  `FIX-AASYSTEM-UNPACK-BUGS` (PR #101) already deferred exactly this as out of scope; this lot does
  not reopen it.
- S-300's `NoCrate` "TEL D" part — no corresponding `spawnableCrates` entry exists, so it cannot be
  affected by this bug; nothing to fix there.
- NASAMS, BUK, KUB — no `NoCrate` parts in these templates at all.

## Further Notes

- No ADR: an internal consistency fix inside one function's existing destroy loop, with the one
  real alternative (removing the catalogue entries) considered and rejected for a documented
  reason that fits in this PRD — not a architectural trade-off.
- Direct precedent for "fix the generic mechanism once rather than per-template": this PRD's own
  scope decision mirrors `FIX-BEACON-FM-POOL-GAP`'s choice to fix the root generator rather than
  patch each caller.
