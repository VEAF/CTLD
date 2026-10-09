# FIX-REVIEW-HYGIENE-A

**Status:** merged (PR #241). Compacted from `FIX-REVIEW-HYGIENE-A/` on 2026-10-09; the ticket files live on in git history.

Lot A of the automated review of `develop` (issues #237, #239): the `EXTR_` group scan matches the bare prefix `EXTR`, so any pre-placed group named `EXTRACTION…` silently becomes extractable (anchored `^EXTR_` + negative test); and the comment justifying the aiZones collision check still describes the parsed-name key removed by ADR 0020 (comment rewrite only, no code change).

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-extr-prefix-anchored-with-underscore` | ✅ done | 01 — EXTR_ scan matches the prefix with its underscore |
| `02-aiz-collision-comment-and-finalization` | ✅ done | 02 — aiZones collision comment rewritten, CHANGELOG and index finalized |

## PRD

## FIX-REVIEW-HYGIENE-A — EXTR_ prefix matched without its underscore, and a stale aiZones comment

**Status:** ✅ done

Formalizes two findings of the automated code review of `develop` (GitHub issues #237 and #239),
grouped as the first, lowest-risk lot of that review. Both findings were re-read against the current
`develop`: the defects are still present. Written directly from the issues, with no `grill-with-docs`
session, because both are tightly scoped and carry no open design question.

### Problem Statement

**EXTR_ scan too wide (#237).** The `EXTR_<name>` naming convention is documented everywhere as a prefix
that includes its underscore, but the init-time scan of pre-placed groups tests the bare four letters
`EXTR`. A mission maker who names an ordinary group `EXTRACTION Alpha`, `EXTRA Fuel Trucks` or
`EXTREME Recon 1` — with no CTLD intent at all — finds it registered as an extractable group: any
transport of its coalition can board it, and the 130 kg per live unit fallback applies to it, so a heavy
group becomes transportable by an aircraft that should not take it. The scan covers RED, BLUE and NEUTRAL,
so a civilian group is hit as well. The only trace is an `INFO` line in the startup log. The existing
negative test only covers a name that *contains* `EXTR_` (fails on the start anchor), so the blind spot is
invisible to CI.

**Stale comment (#239).** The comment that justifies the `aiZones` name-collision check describes, in the
present tense, a mechanism that `FIX-AUTODISCOVERED-ZONE-FULLNAME-KEY` (PR #210, ADR 0020) removed:
auto-discovered troop zones register under their parsed short name. They now register under their full
DCS name. ADR 0020 and the mission-maker zones page were updated; this comment is the last place that
asserts the old behaviour, and the one a maintainer reads first. A wrong comment gets believed: someone
could "fix" the registration key to match it (reintroducing the collision the ADR removed), or delete the
check believing it dead, when the ADR keeps it on purpose as a defensive guard.

### Solution

The scan registers a group only when its name starts with exactly `EXTR_`; any other name that merely
begins with `EXTR` is left alone. The collision-check comment is rewritten to say what the check does
today, following ADR 0020's reasoning, with no change to the check itself.

### User Stories

1. As a mission maker, I want only groups named `EXTR_<name>` to become extractable, so that an ordinary
   group whose name happens to start with `EXTR` is not boardable by my players.
2. As a mission maker, I want a group named `EXTRACTION Alpha` to be ignored by the EXTR_ scan, so that I
   do not have to rename unrelated groups to avoid an invisible side effect.
3. As a mission maker, I want a group named `EXTRA Fuel Trucks` or `EXTREME Recon 1` to stay untouched, so
   that heavy vehicles are not made transportable by accident.
4. As a mission maker, I want a neutral civilian group with an `EXTR`-prefixed name to stay untouched, so
   that the NEUTRAL side of the scan does not catch groups I never meant for CTLD.
5. As a mission maker, I want `EXTR_<name>` to keep working exactly as documented, for RED, BLUE and
   NEUTRAL groups, so that the convention keeps its promise.
6. As a mission maker, I want a group already declared in the `extractableGroups` config list to still be
   registered once only, so that the dedup between the list and the convention is unchanged.
7. As a mission maker, I want a group absent at init (`isExist()` false) to still be skipped silently, so
   that late-activated groups behave as before.
8. As a pilot, I want only the groups the mission maker really declared extractable to show up in
   "Extract from field", so that I am not offered groups that cannot be meant for extraction.
9. As a CTLD developer, I want a busted case with a name starting with `EXTR` but lacking the underscore,
   so that the blind spot of the old pattern is covered by CI.
10. As a CTLD developer, I want the aiZones collision comment to state the current registration key (the
    full DCS name), so that nobody changes the key to match a stale comment.
11. As a CTLD developer, I want the comment to say the check is a deliberately kept defensive guard, so
    that nobody deletes it believing it dead.
12. As a CTLD developer, I want the comment to keep its explanation of why the check lives in the
    aiZones loader and not in the zone-name validation, so that this placement rationale is not lost.
13. As a maintainer, I want the comment to cite ADR 0020, so that a reader can follow the reasoning to its
    source.
14. As a maintainer, I want a `CHANGELOG.md` `[Unreleased]` entry that separates the behaviour fix (EXTR_
    scan) from the comment correction, so that release notes are accurate.

### Implementation Decisions

- **EXTR_ scan:** the init-time group scan of the core manager matches the prefix `EXTR_` anchored at the
  start of the name. The convention is a bare prefix with no positional metadata, so nothing else about the
  scan changes: sides scanned, existence check, dedup against the explicit list, coalition read live from
  the group, `INFO` log line.
- **Behaviour change, deliberately small:** a pre-placed group named `EXTR…` without the underscore stops
  being registered. This is the intended documented behaviour, not a deviation from legacy: the
  convention is new to the rewrite (no equivalent in `migration/source/`), so there is no legacy parity to
  preserve.
- **Side point of #237 (name read before the existence check):** `getName()` is read before
  `isExist()` in the scan, unlike the explicit-list path just above. `coalition.getGroups()` only returns
  existing groups, so there is no observable effect. Decision: align the order **only because the line is
  being touched anyway**, as the issue suggests; it is a one-line reorder with no behaviour change. If it
  turns out to need more than that, it is dropped (surgical mode).
- **aiZones comment:** the explanatory comment above the collision check in the zone manager's aiZones
  loader is rewritten following the text proposed in #239: every auto-discovered zone registers under its
  full DCS name (ADR 0020), so the check can no longer fire by accident on a parsed sub-name and now only
  catches a genuine duplicate of a full Mission Editor zone name; it is kept as a defensive check; the two
  closing sentences about placement (here rather than in the zone-name validation, because `_troopZones`
  is fact at this point) are kept. **No code change**, the check and its report are untouched.
- **No i18n, no config, no catalogue change.** No `ctld.tr` string is added or modified, so the
  dictionaries are unaffected. No `configVersion` change.
- **Docs:** the EXTR_ convention is already documented with its underscore; the mission-maker
  configuration page and the architecture page are re-read and corrected only if they imply the old
  looser matching.
- **CHANGELOG:** both edits are in `src/`, so `[Unreleased]` gets an entry (the `changelog-guard` job
  requires it). Fix entry for the EXTR_ scan; the comment correction is mentioned in the same lot entry.

### Testing Decisions

- A good test here observes external behaviour only: which group names end up registered as extractable
  for a coalition after `_initExtractableGroups`. It does not inspect the pattern or the loop.
- **Seam: the existing core-manager unit spec's `EXTR_ convention` block** (the highest existing seam; no
  new seam is needed). Prior art: the neighbouring cases in the same block (NEUTRAL group registered,
  substring name ignored, absent group skipped silently, dedup with the explicit list).
- New cases, written first and seen failing against the current `^EXTR`: a group named
  `EXTRACTION_Alpha` and a group named `EXTRACTION Alpha` (with a space) are **not** registered; they
  must be added in RED+BLUE and with a NEUTRAL group so the widest side set is covered. The existing
  positive cases (`EXTR_Refugees` on NEUTRAL, etc.) must keep passing unchanged.
- The comment correction has no behaviour and therefore no test; the guarantee is that the existing
  aiZones collision tests keep passing untouched.
- **No live-DCS test:** the change is a pure string-prefix match covered by the busted stubs.
- Gates: `busted tests/ci/`, luacheck clean, `luac5.1 -p` (CI), rebuild of `CTLD.lua` after the `src/`
  change.

### Out of Scope

- The other findings of the same review (#234, #235, #236, #238), handled in their own lots.
- Late-activation support for `EXTR_` groups (a documented, deliberate limitation of the convention).
- Changing the sides scanned, or the 130 kg per-unit fallback weight.
- Warning the mission maker about a near-miss name such as `EXTRACTION`. The scan simply ignores it.
- Any change to the aiZones collision check itself, to ADR 0020, or to the zone docs.

### Further Notes

- Source issues: #237 (EXTR_ prefix) and #239 (stale comment), found by an automated review of `develop`
  at `7535ba0`.
- The PR should reference both with `Fixes #237` and `Fixes #239`.
- Before opening the PR: run `merge_CTLD.ps1` to regenerate the i18n dictionaries (no key expected to
  change; this confirms it).
