# TOOLING-DEPENDABOT-CONFIG — declare every dependency ecosystem to Dependabot, grouped and capped

**Status:** ⬜ ready

Follows the Dependabot pull request #223 (an automatic npm security update nobody had configured) and a
`grill-with-docs` session held 2026-10-01. No ADR: the decision is reversible by editing one file.

## Problem Statement

`.github/dependabot.yml` has covered only the GitHub Actions, weekly, since the pipeline was created on 2026-07-07.
The repository has four other places that declare dependencies — the web app's npm packages, the ctld-tools
Poetry project, the documentation requirements and the build's translation requirements — and none of them is
declared to Dependabot. They are reached only through GitHub's default security updates, which ignore the file.

The result, seen in the history, is noise a maintainer has to sort out by hand: one pull request per dependency,
no cadence, no cap, and duplicates such as the two `vitest` 3 → 5 bumps (#193 and #194) that both failed CI for the
same reason, while the latest one (#223, `devalue`) arrived unannounced. Nothing guards against the next
new manifest being left out the same way.

## Solution

`dependabot.yml` declares all five places explicitly, with a monthly cadence (the Actions stay weekly), one grouped
pull request per ecosystem for minor and patch updates, each major version in its own pull request, the same
grouping applied to security updates, a cap on open pull requests, and Conventional-Commit prefixes. A CI test fails
when a manifest in the repository is not covered by the file, and the developer documentation says how to handle a
Dependabot pull request.

## User Stories

1. As a maintainer, I want every dependency manifest of the repository declared to Dependabot, so that updates
   follow one policy instead of GitHub's defaults.
2. As a maintainer, I want minor and patch updates of one ecosystem in a single monthly pull request, so that I
   review one change instead of a stream of small ones.
3. As a maintainer, I want each major version update in its own pull request, so that the update most likely to
   break the build is read and tested alone.
4. As a maintainer, I want security updates grouped by the same rule, so that they do not bypass the policy, while
   still arriving as soon as an alert appears.
5. As a maintainer, I want a cap on open Dependabot pull requests per ecosystem, so that a series of version
   bumps does not bury the pull request list.
6. As a maintainer, I want duplicate pull requests for the same bump to stop appearing, so that I do not close one
   of two identical failing pull requests by hand.
7. As a maintainer, I want the GitHub Actions to keep their weekly cadence and `ci` prefix, so that nothing changes
   for the part that already works.
8. As a maintainer, I want npm and Python updates to use a `chore(deps)` prefix (`deps-dev` for development
   dependencies), so that the history stays in Conventional Commits.
9. As a maintainer, I want the web app's npm packages covered, so that its updates stop depending on GitHub's
   default behaviour.
10. As a maintainer, I want the ctld-tools Poetry project covered, so that its Python dependencies and lock file are
    updated under the same policy.
11. As a maintainer, I want the documentation requirements covered, so that the documentation toolchain does not
    silently age.
12. As a maintainer, I want the build's translation requirements covered, for the same reason.
13. As a contributor, I want a CI failure that names the uncovered manifest and what to add, so that a new
    `package.json` or `requirements.txt` is never left unmonitored.
14. As a contributor, I want the guard to run when only `dependabot.yml` changes, so that breaking the file is
    caught before it merges.
15. As a maintainer, I want a written procedure for a Dependabot pull request (merge when CI is green, read the
    release notes of a major, close to ignore, never reopen a duplicate), so that anyone on the team handles one the
    same way.
16. As a maintainer, I want that procedure in English and French in the developer documentation, so that it matches
    the rest of the published pages.
17. As a maintainer, I want the rule "every new manifest is declared in `dependabot.yml`" stated where
    contributors read the workflow, so that the guard's message is not the first they hear of it.

## Implementation Decisions

- **Ecosystems declared, five places:** the GitHub Actions (root, unchanged: weekly, `ci` prefix); npm for the web
  app; pip for the ctld-tools Poetry project (the `pip` ecosystem reads Poetry and its lock file); pip for the
  documentation requirements; pip for the build's translation requirements.
- **Cadence:** monthly for npm and pip; weekly for the Actions. Security updates are not held to the cadence: they
  open as soon as an alert appears.
- **Grouping:** one group per ecosystem for minor and patch updates; a major update is never grouped and gets its
  own pull request. A group also applies to security updates, so they follow the same rule.
- **Cap:** at most three open pull requests per ecosystem.
- **Commit messages:** `ci` for the Actions; `chore` with the scope included for npm and pip, which yields
  `chore(deps)` and `chore(deps-dev)`.
- **Guard:** a test in the ctld-tools Python suite reads the Dependabot file and the repository's manifests (npm
  `package.json` outside `node_modules`, `pyproject.toml`, `requirements*.txt`, the workflows folder for the Actions)
  and fails, naming the uncovered manifest and the entry to add, when one has no covering entry. The
  `python-quality` workflow also runs when `.github/dependabot.yml` changes.
- **Documentation:** the developer workflow page, English and French, gets a short section on Dependabot pull
  requests and on the "declare every new manifest" rule; the changelog needs no entry (no code under `src/`).
- Not an ADR: no hard-to-reverse or surprising choice; the policy is one file.

## Testing Decisions

- A good test fails for a repository state a maintainer can create: add a manifest without an entry, remove an entry,
  break the file. It does not assert how Dependabot behaves, which only GitHub can show.
- **Seam:** the repository itself, read by the guard test: the real `dependabot.yml` against the real manifests.
  Prior art: the catalogue-shape guard and the other repository-reading tests of the ctld-tools suite.
- The guard is proven against a deliberately changed fixture (a manifest with no entry) in its own test.
- Dependabot's own behaviour (grouping, cap, cadence) cannot be tested locally; it is checked on GitHub after the
  merge (the dependency graph page reports a parse error) and over the following month.

## Out of Scope

- Merging or closing individual Dependabot pull requests (done case by case).
- Enabling or disabling Dependabot alerts or security updates in the repository settings.
- Auto-merge of Dependabot pull requests (the repository does not allow auto-merge).
- Pinning or upgrading any dependency itself.
- A `renovate` or other updater.

## Further Notes

- History seen: Dependabot pull requests #2–#146 were Actions bumps; #193/#194 were duplicate `vitest` bumps that
  failed CI until `FIX-CTLD-TOOLS-WEB-NODE-TYPES-GAP` fixed the type configuration; #223 was the `devalue` security
  update merged on 2026-10-01.
- `missions/Test_CTLDNEXT_01.miz`, its copies and `tests/dcs/dev/diag/diag_bbox_draw.lua` must not be committed.
