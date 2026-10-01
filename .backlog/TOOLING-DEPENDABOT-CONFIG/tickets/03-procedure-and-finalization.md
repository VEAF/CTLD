# 03 — Written procedure for Dependabot pull requests, and finalization

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — TOOLING-DEPENDABOT-CONFIG](../PRD.md). Stories 15 to 17.

## What to build

The developer workflow page, English and French, gets a short section on Dependabot pull requests: what the policy
is (monthly grouped minor and patch updates, one pull request per major, security updates grouped but immediate),
how to handle one (merge when CI is green; read the release notes of a major before merging; close a pull request to
ignore it; never reopen a duplicate), and the rule that every new dependency manifest is declared in
`.github/dependabot.yml`, with the CI guard as the safety net.

Finalization: the PRD status is set to done and the lot's index line in the backlog README is set to
`merged (PR #NN)` in the delivering PR. No changelog entry: nothing under `src/` changes.

## Acceptance criteria

- [ ] The English and French pages carry the same section, matching the delivered `dependabot.yml` and guard.
- [ ] The section states the rule "declare every new manifest" and points at the guard.
- [ ] The PRD status is done and the index line is `merged (PR #NN)`.
- [ ] `pytest`, `ruff check`, `ruff format --check` pass on the whole branch.

## Blocked by

- [02 — CI guard](02-coverage-guard.md)
