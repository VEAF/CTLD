# 02 — Correct the overstated FIX-I18N-STALE-COMMENT-PARSING impact claim

**Status:** ready
**Lot:** FIX-I18N-PURGE-SUPERSEDED

## Problem

The `[Unreleased]` CHANGELOG entry for `FIX-I18N-STALE-COMMENT-PARSING` (PR #119) states the 56
wrongly-staled keys caused *"broken/missing text in F10 menus and the AA system UI, in every
language, not just KO/ES"*. The lot's PRD says the bug was *"breaking F10/AA-system text in every
language"*.

Both are wrong. `ctld.tr()` falls back *active language → EN → the key itself*, and the key is the
English text, so a missing entry renders as correct English rather than as blank or broken text.
Replaying the pre-fix dictionaries through that chain in Lua 5.1 returns `HAWK Launcher` for
`tr(en)`, `tr(fr)` and `tr(ko)` alike. No code path reads `ctld.i18n[...]` directly outside the i18n
module, so nothing bypasses the fallback.

`[Unreleased]` freezes into the 2.0.0 section at the stable tag, so this would ship as the release's
reference description of the bug.

## What to do

- Rewrite the impact sentences in `CHANGELOG.md` and in
  `.backlog/FIX-I18N-STALE-COMMENT-PARSING/PRD.md` to the measured symptom: those labels rendered
  **in English instead of the active language** in FR/ES/KO, English being unaffected.
- Keep the rest of both entries as-is — the root-cause analysis, the scope and the recovery of the
  FR/ES/KO translations from the commented lines are all accurate.
- State the fallback chain explicitly, so a reader can tell why a missing key is not a blank label.

## Acceptance

- [ ] Neither file claims text was broken, missing or `nil` on screen.
- [ ] Both name the fallback chain and the English-unaffected conclusion.
- [ ] The 56-key root cause and the recovery narrative are unchanged.
