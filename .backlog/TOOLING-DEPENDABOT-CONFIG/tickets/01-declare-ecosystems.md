# 01 — Declare the five dependency places to Dependabot, grouped and capped

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — TOOLING-DEPENDABOT-CONFIG](../PRD.md). Stories 1 to 12.

## What to build

`.github/dependabot.yml` declares every place that carries dependencies, with one policy:

- the GitHub Actions at the root (unchanged: weekly, `ci` prefix);
- npm for the web app of ctld-tools;
- pip for the ctld-tools Poetry project, for the documentation requirements and for the build's translation
  requirements.

For npm and pip: monthly cadence; one group per ecosystem for minor and patch updates and no group for a major
(each major gets its own pull request); the same grouping applied to security updates, which still open as soon as
an alert appears; at most three open pull requests per ecosystem; commit messages `chore` with the scope included
(`chore(deps)`, `chore(deps-dev)`).

Dependabot's own behaviour cannot be exercised locally. The file is checked here as valid YAML with the intended
entries; GitHub's dependency graph page reports a parse error after the merge, and the first monthly run shows the
grouping.

## Acceptance criteria

- [x] The file declares the Actions, npm for the web app, and pip for ctld-tools, `docs/` and `tools/build/`.
- [x] npm and pip entries are monthly, capped at three open pull requests, with `chore` / scope-included commit
      messages; the Actions entry is unchanged.
- [x] Each npm and pip entry has a minor-and-patch group, no group covering majors, and a group applying to
      security updates.
- [x] The file parses as YAML and every entry has the keys Dependabot requires (ecosystem, directory, schedule).

## Blocked by

None - can start immediately.
