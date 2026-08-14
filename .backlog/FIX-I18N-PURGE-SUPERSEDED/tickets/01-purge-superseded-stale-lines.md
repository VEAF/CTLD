# 01 — Purge superseded `-- STALE:` lines from the dictionaries

**Status:** ready
**Lot:** FIX-I18N-PURGE-SUPERSEDED

## Problem

PR #119 revived 56 wrongly-staled keys by appending fresh live lines at end of file, leaving the
`-- STALE:` lines they supersede in place. 225 keys across the four dictionaries now exist twice —
once commented and inert, once live. A translator editing the first occurrence they find edits the
dead one, silently.

## What to do

In `tools/build/generate_i18n_dicts.ps1`, add a third category next to `MISSING` and `STALE`:

- **`SUPERSEDED`** — a key that appears on a commented-out line *and* on a live line in the same
  dictionary. Reported in dry-run, deleted (commented line only) under `-Apply`.

Implementation notes:

- A new `Get-DeadDictKeys` helper mirrors `Get-DictKeys` but keeps only the commented lines, so the
  two stay symmetrical and both use the same entry regex.
- Deletion targets a line that starts with `--` **and** carries the `ctld.i18n["<lang>"]["<key>"]`
  entry for that exact key — a commented `__keep_en` member (`-- ["Old Mod Name"] = true`) does not
  match the entry pattern and is untouched.
- Escape the key with `[regex]::Escape` (keys contain `%`, `(`, `[`, `?`, `!`).
- Delete *every* commented occurrence of the key, not just the first.
- The early `OK` short-circuit must account for the new category, otherwise the purge never runs on
  a dictionary that is otherwise in sync — which is exactly today's state.
- No `translation_version` bump when the purge is the only change (see PRD, out of scope).
- Preserve CRLF endings and UTF-8-without-BOM, like the existing write path.

Then run `-Apply` and commit the resulting dictionary changes.

## Acceptance

- [ ] Dry-run lists `SUPERSEDED` entries before the purge, `OK` after.
- [ ] 225 commented lines removed (en 66, fr 66, es 59, ko 34); no key both commented and live.
- [ ] 303 live keys per dict, unchanged; the 582 genuinely-dead commented lines untouched.
- [ ] `translation_version` unchanged on all four dicts.
- [ ] `pytest tools/build/` green, `busted tests/ci/` green, `CTLD.lua` rebuilds.
