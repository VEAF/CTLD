# 02 — Force English anchors on ALL FR headings (not just H1) + fix intra-page links

Status: 🚧 in progress
Type: AFK
Repo: CTLD
GitHub: —

## Context

Ticket 01 forced the English anchor only on the page **H1**. The requirement ("anchors must be
English, text French") applies to **every** heading: H2/H3/… on the FR pages still carried French
slugs (e.g. `configuration-cote-mission` vs the EN `mission-configuration`), so deep links did not
line up across the EN and FR builds.

## What to build

1. Add an explicit `{ #english-slug }` to every FR heading whose natural French slug diverges from
   the EN page's slug. Pair headings **positionally** with the EN page (as rendered by mkdocs);
   abort a file if counts or levels don't match. Leave headings whose text is identical EN/FR
   untouched (their slug is already English).
2. Repoint intra-page anchor links `](#french-slug)` in the FR pages to the new English anchors.
   The visible link text stays French.

Tooling: throwaway Python scripts driving a real `mkdocs build` to read the authoritative slugs
(not committed).

## Acceptance criteria

- [ ] Every FR page's rendered heading ids equal the EN page's (verified: 43/43 pages, 0 diverge).
- [ ] No broken intra-page anchor link in any FR page (verified: 27 links, 0 broken).
- [ ] Displayed heading text and link text remain French.
- [ ] `mkdocs build --strict` clean.
