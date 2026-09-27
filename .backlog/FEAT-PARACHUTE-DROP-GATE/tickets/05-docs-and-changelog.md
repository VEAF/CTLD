# 05 — Document `enableParachuteDrop`, CHANGELOG entry

**Status:** ⬜ ready

**Blocked by:** tickets 01, 02, 03, 04 — documents the finished, fully-tested behavior.

## What to build

Add a new `### Parachute` subsection to `docs/mission-maker/configuration.md` and
`configuration.fr.md`'s "## Global settings" (same shape as the existing `### Crates & slingload`
subsection), documenting `enableParachuteDrop` — default `true`, master switch ahead of
`canParachuteDrop`, no error shown when it hides an entry.

Add a `CHANGELOG.md` `[Unreleased]` entry for the new setting.

## Watch out

- The `parachute` schema group's other settings (`parachuteMinAltitude*`,
  `parachuteDescentRate*`, `parachuteInertiaFactor`, `parachuteLateralDrift*`) are **not**
  documented in `configuration.md`/`.fr.md` today either — this is pre-existing debt, unrelated to
  this lot. Document only `enableParachuteDrop` here; backfilling the rest of the group is a
  separate concern (candidate for `dev/roadmap.md`'s own "générer les tableaux de config... depuis
  le schéma" entry, not this ticket).
- Keep EN and FR in sync — both files get the same new subsection, same content.
- This ticket runs last (blocked by 01-04) precisely so the docs describe verified, shipped
  behavior rather than a plan.

## Acceptance

- `docs/mission-maker/configuration.md` and `.fr.md` each gain a `### Parachute` subsection
  documenting `enableParachuteDrop` (default, behavior, relationship to `canParachuteDrop`).
- `CHANGELOG.md` `[Unreleased]` has an entry for the new setting.

## Tests

None — documentation and changelog only.
