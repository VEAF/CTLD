# FIX-I18N-PURGE-SUPERSEDED — purge superseded `-- STALE:` lines, correct the FIX-I18N-STALE-COMMENT-PARSING changelog entry

## Context

Two loose ends left by [`FIX-I18N-STALE-COMMENT-PARSING`](../FIX-I18N-STALE-COMMENT-PARSING/PRD.md)
(PR #119), found while reviewing that lot.

### 1. The CHANGELOG overstates the bug it fixed

The `[Unreleased]` entry for that lot states the 56 wrongly-staled keys meant
*"broken/missing text in F10 menus and the AA system UI, in every language, not just KO/ES"*,
and the lot's own PRD says the bug was *"breaking F10/AA-system text in every language"*.

Measured rather than assumed — the dictionaries from `cbd7b93^` (the commit before the fix)
replayed through `ctld.tr()`'s real fallback chain in Lua 5.1:

```
HAWK Launcher | raw_en=nil | tr(en)=HAWK Launcher | tr(fr)=HAWK Launcher | tr(ko)=HAWK Launcher
Infantry      | raw_en=nil | tr(en)=Infantry      | tr(fr)=Infantry      | tr(ko)=Infantry
```

`ctld.tr()` falls back *active language → EN → the key itself*, and the key **is** the English
text (`src/CTLD_i18n.lua`). So the real in-game symptom was a **loss of translation** — those
labels rendered in English in FR/ES/KO — and **English was unaffected**, exactly the symptom
FullGas originally reported. Nothing was ever broken, blank or `nil` on screen: no code reads
`ctld.i18n[...]` directly outside the i18n module (the only occurrences in `src/scenes/` are
*writes*), so every read goes through the fallback.

This matters beyond accuracy: `[Unreleased]` freezes as-is into the 2.0.0 section on the stable
tag, so the overstatement would ship as the reference description of the release.

### 2. 225 superseded `-- STALE:` lines still sit in the dictionaries

PR #119 revived the 56 keys by **appending** fresh live lines at end of file, without removing
the commented-out lines they supersede. A key therefore appears twice — `"HAWK Launcher"` is
`CTLD_i18n_en.lua:78` (commented, inert) and `:596` (live).

| Dict | live | commented | **both** (superseded) | commented only (genuinely dead) |
|------|-----:|----------:|----------------------:|--------------------------------:|
| en   |  303 |       240 |                  **66** |                             174 |
| fr   |  303 |       242 |                  **66** |                             176 |
| es   |  303 |       235 |                  **59** |                             176 |
| ko   |  303 |        90 |                  **34** |                              56 |

Functionally inert — the parser fixed in #119 skips them. But a translator who opens the file,
finds the first occurrence and edits it will never see their work render. That is the next silent
trap in this series, and it is cheap to close now.

Audited before deciding to delete: of the 225 pairs, **218 carry an identical value** and
**7 hold an older wording the live line already replaced** (e.g. FR `Check Cargo`:
live `Vérifier la cargaison` vs commented `Vérifé chargement`). **Zero** pairs have an empty live
value against a translated commented one, so no translation is lost by deleting the commented side.

## Scope

- Correct the two overstated claims (CHANGELOG `[Unreleased]`, and the `FIX-I18N-STALE-COMMENT-PARSING`
  PRD which is the lot's own record) to state the measured symptom.
- Teach `generate_i18n_dicts.ps1` to purge a commented entry whose key is live — reported as
  `SUPERSEDED` in dry-run, deleted under `-Apply`. Fixing it in the generator rather than with a
  one-shot script is what stops the duplicates coming back the next time a key is revived.
- Apply it: 225 lines removed across the four dictionaries.

## Out of scope

- **The 582 genuinely dead commented lines** (keys with no live counterpart) stay. They are the
  archive that let PR #119 recover the FR/ES/KO translations of the 56 revived keys instead of
  re-translating them — deleting them would throw away the same safety net for the next revival.
- No `translation_version` bump for a purge: the policy bumps a dict when *its content* changes so
  `ctld.i18n_check()` can flag a dict lagging behind EN. Removing inert comments changes no
  translation, and a bump would signal drift that did not happen.
- No Pester suite for `generate_i18n_dicts.ps1` — `tools/build/` has never had PowerShell tests
  (only pytest on the `.py` files); introducing a test framework is its own lot.

## Acceptance

- `generate_i18n_dicts.ps1` dry-run reports `SUPERSEDED` for a commented entry whose key is live.
- After `-Apply`, no key exists both commented and live in any of the four dictionaries.
- Dry-run reports `OK` on all four dicts afterwards; 303 live keys per dict, unchanged.
- `pytest tools/build/` and `busted tests/ci/` stay green; `CTLD.lua` rebuilds.
- The CHANGELOG no longer claims text was broken or missing in English.

## Tickets

| Ticket | Status | Description |
|--------|--------|-------------|
| `01-purge-superseded-stale-lines` | ready | Generator purge + application to the four dicts |
| `02-correct-changelog-claim` | ready | CHANGELOG + PRD wording corrected to the measured symptom |
