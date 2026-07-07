# 04 — French translation (pilot + mission-maker)

Status: ⬜ ready
Type: AFK

## What to build

Author the `*.fr.md` counterpart of every `docs/pilot/*.md` and `docs/mission-maker/*.md` page
(mkdocs `docs_structure: suffix` i18n). Full FR translation — no EN/FR mixing within a sentence.

Code identifiers, config keys, DCS type strings, file paths, F10 menu entry labels (in-game UI
strings) and established DCS/CTLD domain terms stay in their original form; prose is translated.

## Acceptance criteria

- [ ] Each EN page under `docs/pilot/` and `docs/mission-maker/` has a `*.fr.md` sibling.
- [ ] Translations complete and technically faithful.
- [ ] `mkdocs build --strict` produces a clean FR tree.

## Blocked by

01, 02 (EN content must be locked before translating).
