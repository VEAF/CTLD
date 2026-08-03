# 03 — a help panel worth pressing, with a version-aware link

**Status:** todo

Depends on: 01 (the version), 02 (what the link can point at).

## Where it starts from

`web/src/lib/HelpPanel.svelte` (267 lines) is already better than static prose: it derives the
setting count, the family list and the data-table inventory from the schema and the open catalogue,
so it cannot go stale. What it does not do is tell a Mission Maker **what to do** — and it links
nowhere.

## What changes

- **The link.** `https://veaf.github.io/CTLD/<docs>/` where `<docs>` is `dev` when the tool's version
  carries an `-rc` suffix, and the exact `x.y.z` otherwise (PRD decision). One helper, one rule, no
  table to maintain: it starts pointing at real versioned pages the day ticket 02's stable path runs.
  Deep links to the pages that matter — configuration, zones, the migration guide — not only the
  site root.
- **The tool's version, displayed.** A Mission Maker reporting a problem should be able to read it
  off the panel.
- **What to do, not only what is here.** The panel should answer the three questions a first-time
  user actually has: how do I install CTLD into my mission (the ticket-04 journey), what do I edit
  first, and how do I check it worked. Short, and linked to the documentation for the long form.
- Keep every derived-from-the-schema part. It is the reason the panel does not rot.

## Watch out

Do not fork the documentation into the panel. Anything longer than a paragraph belongs on the site,
behind the link — otherwise there are two texts to keep true, and the panel is the one nobody
remembers to update.

## Acceptance

- The panel shows the tool's version, and the link resolves — for a pre-release build too.
- A first-time user finds the install journey without leaving the tool.
- No hardcoded version string, and no hardcoded documentation version, in the frontend.
- FR and EN both complete: the panel is already translated, so new strings go through the same i18n
  path.

## Tests

- Frontend: the link is built from the version reported by the API — an `-rc` version yields `dev`, a
  stable version yields itself.
- Frontend: the panel renders the version from the API, not from a constant.
