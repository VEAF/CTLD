# 06 — mkdocs nav, link fixes & retire old sources (EN)

Status: ✅ done
Type: AFK

## What to build

Wire the new developer section into the site and remove the migrated sources:

- Update `mkdocs.yml` `nav`: replace the flat `Developer: dev-guide.md` + `API Reference:
  api-reference.md` entries with a **Developer** section listing the new pages (index, workflow,
  architecture, subsystems, events, i18n, building-and-testing, migration-v1-v2, api-reference,
  design-spec).
- Remove `docs/dev-guide.md` and `docs/api-reference.md` (content migrated).
- Remove `migration/specs/` (all unique content migrated into `docs/developer/`). Leave
  `migration/source/` untouched (immutable legacy monolith).
- Fix all broken internal links and content gaps flagged in DOC-MKDOCS so
  `mkdocs build --strict` is clean.

## Acceptance criteria

- [ ] `mkdocs build --strict` succeeds with **no warnings** (EN + FR trees).
- [ ] Nav shows the Developer section with all new pages.
- [ ] `docs/dev-guide.md`, `docs/api-reference.md`, `migration/specs/` are gone.
- [ ] `migration/source/` untouched.
- [ ] No dangling references to removed files anywhere in the repo.

## Blocked by

01–05 (all EN content pages), 07 (FR pages must exist for `--strict` i18n build).
