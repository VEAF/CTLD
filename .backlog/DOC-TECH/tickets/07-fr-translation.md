# 07 — French translation of the developer docs

Status: ⬜ ready
Type: AFK

## What to build

Author the `*.fr.md` counterpart of every `docs/developer/*.md` page (mkdocs
`docs_structure: suffix` i18n). Full FR translation — no EN/FR mixing within a sentence.

Pages: `index`, `workflow`, `architecture`, `subsystems`, `events`, `i18n`,
`building-and-testing`, `migration-v1-v2`, `api-reference`, `design-spec`.

Code identifiers, API names, type strings, file paths and DCS terms stay in their original form;
prose is translated.

## Acceptance criteria

- [ ] Each `docs/developer/*.md` has a `*.fr.md` sibling.
- [ ] Translations are complete (no untranslated EN prose left) and technically faithful.
- [ ] `mkdocs build --strict` produces a clean FR tree.

## Blocked by

01–05 (EN content must be locked before translating).
