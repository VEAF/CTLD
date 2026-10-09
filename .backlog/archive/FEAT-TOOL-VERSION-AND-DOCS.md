# FEAT-TOOL-VERSION-AND-DOCS

**Status:** merged (PR #93). Compacted from `FEAT-TOOL-VERSION-AND-DOCS/` on 2026-10-09; the ticket files live on in git history.

A help button worth pressing, linking to the documentation **of the tool's own version** — which needs two missing bricks. The tool does not know its version (`pyproject.toml` still says `0.1.0`, the API declares `version="2.0"` as a literal, no `--version`), and the published docs have exactly one version (`versions.json` = `dev` only; `docs.yml` deploys on push to `develop`, nothing on a tag). Decided: one source of truth — the tool reports `ctld.VERSION` — plus `mike deploy` on `published-v*` tags, where a **stable** moves the `latest` alias and a **pre-release does not**, same discipline as `published-latest` for downloads. Until stable ships, the link rule is `dev` for any `-rc` version and the exact `x.y.z` otherwise: honest today, correct by itself the day a stable is tagged.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-one-version-for-the-tool` | done | 01 — the tool reports the CTLD version, from one source |
| `02-publish-versioned-docs` | done | 02 — publish the documentation per version, on the tag |
| `03-help-panel-and-the-link` | done | 03 — a help panel worth pressing, with a version-aware link |

## PRD

## FEAT-TOOL-VERSION-AND-DOCS — the tool knows its version, and points at the matching documentation

**Status:** open.

Opened 2026-08-01, alongside `FEAT-ONE-CLICK-INSTALL`. The ask: a help button worth pressing, with a
link to **the documentation of the tool's own version**.

### Two bricks are missing

**The tool does not know its version.** `tools/ctld-tools/pyproject.toml` says `0.1.0` and has never
been bumped; the FastAPI app declares `version="2.0"` as a literal; there is no `--version` on the
CLI. Nothing in the tool can name the CTLD release it belongs to.

**The published documentation has one version, `dev`.** Verified in
`https://veaf.github.io/CTLD/versions.json`: a single entry, `{"version": "dev", "title": "dev",
"aliases": []}`. `docs.yml` runs `mike deploy --push --update-aliases dev` on every push to
`develop`, and nothing deploys on a tag. So there is no `2.0.0-rc3` documentation to link to.

A help link that promises a version and lands on the only version there is would be a lie by
omission. Both bricks belong in this lot.

### Decisions taken (David, 2026-08-01)

**The documentation gets a version tag — but not yet.** We are in pre-release; the versioned
documentation arrives with the first stable. Until then the link must degrade honestly rather than
point at a page that does not exist.

The rule, which needs no maintenance once written: the tool derives its documentation URL from its
own version — **`dev` while the version carries an `-rc` suffix, the exact `x.y.z` otherwise**. It
becomes correct on its own the day a stable ships and `mike deploy 2.0.0` runs, with no code change.
That is the "bricolage" the decision asks for, and it has an expiry date built in.

### Definition of done

- One source of truth for the version: the tool reports the same string as `ctld.VERSION`, wherever
  it is displayed.
- `ctld-tools --version` works, and the exe smoke-check asserts it.
- The help panel links to documentation that exists, for every version of the tool, today included.
- When the first stable is tagged, versioned documentation is published and the link follows —
  without editing the tool.

### Out of scope

- Rewriting the documentation content. The help panel gains a link and better explanations of the
  tool; the pages themselves are `FEAT-ONE-CLICK-INSTALL` ticket 04's business.
- Version-gap detection, which already exists and is a different question (the *config's* version,
  not the tool's).
