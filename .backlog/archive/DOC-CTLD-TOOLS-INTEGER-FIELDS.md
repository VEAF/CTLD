# DOC-CTLD-TOOLS-INTEGER-FIELDS

**Status:** merged (PR #202). Compacted from `DOC-CTLD-TOOLS-INTEGER-FIELDS/` on 2026-10-09; the ticket files live on in git history.

Found during a post-merge documentation audit (2026-09-27): `FIX-CTLD-TOOLS-INTEGER-FIELDS` (PRs #188-191) changed `ctld-tools`' UI behavior (whole-number fields now enforce an integer step; `validate` gained a new `WARNING`) without ever touching `docs/mission-maker/`. Updates `ctld-tools.md`/`.fr.md`'s "Editing your configuration" and "Validation" sections — the two sentences that went stale — nothing else.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-document-integer-field-behavior` | ✅ done | 01 — Document whole-number field behavior in `ctld-tools.md`/`.fr.md` |

## PRD

## DOC-CTLD-TOOLS-INTEGER-FIELDS — document `ctld-tools`' whole-number field behavior

**Status:** ✅ done (PR #202).

Found during a post-merge documentation audit (2026-09-27, covering the last 10 merged PRs): the
`FIX-CTLD-TOOLS-INTEGER-FIELDS` lot (PRs #188-191, merged 2026-09-24) changed `ctld-tools`' UI
behavior — a whole-number-only field now enforces an integer step and rounds a typed decimal, and
`ctld-tools validate` gained a new `WARNING` for a fractional value that bypassed the UI — without
touching `docs/mission-maker/` on any of its 4 PRs. No ADR or design decision is being revisited
here; this lot only closes the documentation gap.

### Problem Statement

`docs/mission-maker/ctld-tools.md` / `.fr.md` describes the editor generically: "the right editor
for its type — a switch for on/off, a dropdown for fixed choices, a number or text box otherwise."
This sentence predates the integer/continuous distinction and no longer reflects what a Mission
Maker actually sees: some number fields are now whole-number-only (a rejected/rounded decimal),
others remain continuous. The `### Validation` section similarly doesn't mention the new
`WARNING` a hand-edited YAML's fractional value can trigger. Nothing is factually wrong, but a
Mission Maker reading the doc today gets an incomplete picture of a real, shipped behavior.

### Solution

Update `docs/mission-maker/ctld-tools.md` and `.fr.md` in the two spots the audit identified:

1. **"Editing your configuration"** section: the "a number or text box otherwise" sentence gains a
   short clause distinguishing a whole-number field (soldier/launcher counts, quotas, limits, laser
   codes) from a continuous one (weights, distances, durations) — mirroring the distinction
   `ADR 0018` and the `FIX-CTLD-TOOLS-INTEGER-FIELDS` PRD already settled, described here in plain
   Mission-Maker language, not implementation terms.
2. **"Validation"** section: the example problem list ("unknown DCS unit types, duplicate crate
   weights, and so on") gains a mention that a whole-number field holding a fractional value (from
   a hand-edited YAML, or a configuration authored before this behavior existed) is one of the
   things the panel catches.

### User Stories

1. As a Mission Maker reading `ctld-tools.md` for the first time, I want to know that some numeric
   fields only accept whole numbers, so that I'm not confused when a typed `6.01` rounds or is
   rejected.
2. As a Mission Maker who hand-edited a YAML config (or reopened one authored before this
   behavior existed) and sees a validation warning about a fractional value, I want the docs to
   explain what that warning means, so that I understand it's a whole-number field being enforced,
   not a structural problem with my configuration.
3. As a documentation maintainer, I want this fix scoped to the two sentences that actually went
   stale, not a full per-field catalogue of which settings are integer-only, so that this lot stays
   proportionate to the gap found (a field-by-field list would duplicate the schema itself and rot
   the same way `configuration.md`'s settings tables already do — see `dev/roadmap.md`'s "générer
   les tableaux de config... depuis le schéma" entry for that pre-existing, separate problem).

### Implementation Decisions

- Both edits land in `docs/mission-maker/ctld-tools.md` and `.fr.md` only — no other doc file.
  `configuration.md`/`.fr.md` (the settings-table reference) and `asset-validation.md` (a different
  subsystem, the dev-time asset-check companion) are not in scope: neither claims anything about
  field-level numeric behavior today, so neither went stale.
- No new admonition block (`!!! note`/`!!! tip`) — both edits are short clauses added to existing
  sentences in prose, matching the surrounding style; this isn't substantial enough content to
  warrant its own callout box.
- No change to any other doc identified as a pre-existing, separate gap during the same audit
  (the `parachute` physics settings group's absence from `configuration.md`, noted during
  `FEAT-PARACHUTE-DROP-GATE`; the settings-table/schema duplication itself) — both stay out of
  scope, tracked where they already are.

### Testing Decisions

None — documentation-only change, no code, no test suite applies.

### Out of Scope

- Any change to `ctld-tools`' actual behavior, schema, or `validate.py` — this lot is documentation
  only, closing a gap left by an already-shipped, already-tested feature.
- A full per-field list of which scalar settings / table columns are integer-only — see
  Implementation Decisions above.
- Backfilling any other pre-existing documentation gap surfaced during the same audit (parachute
  physics settings, settings-table/schema duplication) — each belongs to its own future lot if
  picked up.

### Further Notes

No ADR — a documentation correction, not a design decision.
