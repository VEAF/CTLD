# DOC-NAV-I18N

**Status:** ✅ merged (PR #53, #54). Compacted from `DOC-NAV-I18N/` on 2026-08-01; the ticket files live on in git history.

Translate the mkdocs site navigation to French (`nav_translations` under the FR locale) and harmonise every FR page H1 to the `French (dcs-term)` convention with **English anchors** forced via `attr_list` (`# Caisses (crates) { #crates }`), keeping permalinks stable across EN/FR. Drops the obsolete "CTLD Next" name from the integration-testing H1 (EN + FR). Docs only, no `src/`.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-nav-translations-and-h1` | 🚧 in progress | 01 — FR nav_translations + harmonise page H1s (French text, English anchors) |
| `02-english-anchors-all-headings` | 🚧 in progress | 02 — Force English anchors on ALL FR headings (not just H1) + fix intra-page links |

## PRD

## Lot DOC-NAV-I18N — translate the site navigation to French + harmonise page titles

Status: 🚧 in progress
Branch: feature/doc-nav-i18n → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: none (docs only)

### Problem Statement

The published mkdocs site is bilingual (EN default + FR) via `mkdocs-static-i18n`. Two title
problems remain on the FR build:

1. **Navigation is 100 % English on the FR site.** `mkdocs.yml` carries a single `nav:` block
   shared by both locales. The i18n plugin only translates nav labels when a `nav_translations:`
   map is declared under the `fr` locale — which is currently absent. So every tab and sidebar
   entry ("Home", "Pilot", "Troop transport"…) stays in English when the reader switches to FR.

2. **Page H1s are inconsistent.** The `.fr.md` files are mostly translated, but DCS jargon was left
   in English on the Pilot pages (`Crates`, `Beacons`, `Recon`, `Smoke`, `Sling-load`) while the
   Developer pages francised the same notions. A few titles were never translated (`Minefield`,
   `Scenes & FOB`, `Design spec`), and `developer/integration-testing` still carries the obsolete
   project name **"CTLD Next"** in both languages.

### Goal

- FR navigation fully translated via `nav_translations`.
- Every FR page H1 follows the agreed **`French (dcs-term)`** convention (e.g. `Caisses (crates)`),
  so the French reading stays clear while keeping the link to the in-game English labels.
- **Anchors stay English.** The displayed title is French but the heading slug (permalink) is
  forced to the English slug via `attr_list` (`# Caisses (crates) { #crates }`), keeping deep
  links stable and identical across the EN and FR builds.
- Remove the obsolete "CTLD Next" name from the two integration-testing H1s (EN + FR).

### Scope

- `mkdocs.yml`: add the FR `nav_translations` map.
- All `docs/**/*.fr.md`: rewrite the H1 to `French (dcs-term) { #english-slug }`.
- `docs/developer/integration-testing.md` (EN): drop "CTLD Next — " from the H1.

Out of scope: H2/H3 anchors and body text (this lot is about titles only).

### Non-goals

- No `src/` change → no `CHANGELOG` entry (PR labelled `skip-changelog`).
- No new pages, no nav restructuring.

### Acceptance criteria

- [ ] FR site nav labels are all French per the agreed table.
- [ ] Every FR H1 uses `French (dcs-term)` where a DCS term applies, plain French otherwise.
- [ ] Every FR H1 declares an explicit English anchor matching the EN page slug.
- [ ] No "CTLD Next" left anywhere in `docs/`.
- [ ] `mkdocs build --strict` succeeds (or CI docs build is green).
