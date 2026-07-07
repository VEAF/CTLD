# Lot DOC-MKDOCS — documentation publishing infrastructure

Status: ✅ done
Branch: feature/doc-mkdocs → PR → develop
Program: re-tooling CTLD_Next on the VMCT model (see `.backlog/README.md`)

## Problem Statement

The repo has docs under `docs/` but no publishing pipeline. The inherited `ci.yml` even ran
`mkdocs gh-deploy` with no `mkdocs.yml` (broken; removed in CI-REVAMP). There is no site, no
versioning, no bilingual scaffolding.

## Solution

Stand up the mkdocs-material publishing infrastructure on the repo's own GitHub Pages:
`mkdocs.yml` (material theme, `mkdocs-static-i18n` EN default + FR, `mike` versioning) + a `docs.yml`
workflow that deploys to `gh-pages` via mike (`develop` → `dev`, `master` → `latest`).

This lot is **infrastructure only**. The existing `docs/` files stay flat and EN-only; the
role-based restructure (pilot / mission-maker / developer), FR translations, and content refonte
(broken links, gaps) are the DOC-TECH and DOC-USER-ROLES lots.

## Scope

- `mkdocs.yml` — material, i18n (en default, fr with EN fallback), mike, nav over current files.
- `docs/requirements.txt` — mkdocs-material, mkdocs-static-i18n, mike (not shipped).
- `.github/workflows/docs.yml` — build + `mike deploy --push` to gh-pages on develop/master.

## Testing Decisions

- Verified locally: `pip install -r docs/requirements.txt` + `mkdocs build` succeeds and produces
  both `en` and `fr` trees. (Content link warnings are pre-existing Fulgas-doc issues, fixed in
  DOC-TECH.) The deploy is validated by the first `docs.yml` run on merge to `develop`.

## Out of Scope

- Role-based restructure, FR translations, content fixes → DOC-TECH / DOC-USER-ROLES.
- The chatbot (bonus, future).

## Further Notes

One-time repo setting after the first deploy creates `gh-pages`: enable GitHub Pages with source =
`gh-pages` branch (root). Site URL: https://veaf.github.io/CTLD_Next/.
