# 02 — Document `EXTR_` (developer + mission-maker), including the pre-existing `extractableGroups` gap

**Status:** ⬜ ready

**Blocked by:** ticket 01 — documents the finished, tested behavior.

## What to build

**Developer docs** (straightforward): `docs/developer/architecture.md` / `.fr.md`'s INIT-E row and
its "INIT-E detail" paragraph currently describe only the explicit-list read. Extend both to
mention the `EXTR_` scan alongside it (coalition scope, dedup against the explicit list, no
late-activation support).

**Mission-maker docs** (a real gap, found while scoping this lot): `extractableGroups` has **no**
Mission-Maker-facing documentation anywhere today — no row in `docs/mission-maker/configuration.md`
/ `.fr.md`'s settings tables, and `docs/mission-maker/zones.md` doesn't fit (its stated scope is
trigger zones with positional-field names — "a zone name encodes its type and all of its
parameters" — `EXTR_` is neither a zone nor does it have parameters). This ticket adds:
- A table row for `extractableGroups` in `configuration.md`/`.fr.md` (wherever the Troops settings
  table already lives), since documenting `EXTR_` as "an alternative to X" without X ever having
  been documented would be confusing.
- A short prose note (in the same section, or wherever the implementer judges clearest) explaining
  `EXTR_<name>`: name a pre-placed group this way in the Mission Editor and it becomes extractable
  with no config entry needed; no parameters after the prefix; a group named both ways only
  registers once; a group activated after mission start is not picked up.

## Watch out

- Keep EN and FR in sync in both doc pairs.
- Don't invent a `zones.md`-style dedicated page for this — it's one setting plus one naming
  convention, not a new subsystem; over-building the doc structure here isn't warranted.
- This ticket runs last (blocked by 01) so it describes verified, shipped behavior rather than a
  plan.
- Don't attempt to also document the existing JTAC substring match or `SVNT_` prefix as part of
  this ticket — out of scope, `CONTEXT.md`'s new "Auto-discovered group" term already covers them
  at the glossary level; this ticket is about `extractableGroups`/`EXTR_` specifically.

## Acceptance

- `docs/developer/architecture.md` and `.fr.md`'s INIT-E description mentions the `EXTR_` scan.
- `docs/mission-maker/configuration.md` and `.fr.md` each gain a row for `extractableGroups` and a
  clear explanation of `EXTR_<name>`.

## Tests

None — documentation only.
