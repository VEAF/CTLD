# 02 — CI guard: every manifest of the repository is covered by `dependabot.yml`

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — TOOLING-DEPENDABOT-CONFIG](../PRD.md). Stories 13 and 14.

## What to build

A test in the ctld-tools Python suite (run by the `python-quality` workflow) reads `.github/dependabot.yml` and the
repository's manifests — npm `package.json` outside `node_modules`, `pyproject.toml`, `requirements*.txt`, and the
workflows folder for the Actions — and fails when one has no covering entry, naming the manifest and the entry to
add. An entry covers a manifest when its ecosystem matches and its directory is the manifest's folder.

The `python-quality` workflow also runs when `.github/dependabot.yml` changes, so that breaking the file alone is
caught before it merges. The guard is proven against a deliberately changed fixture.

## Acceptance criteria

- [ ] The test passes on the real repository and its `dependabot.yml`.
- [ ] A fixture with a manifest that has no entry makes it fail, with a message naming the manifest, its ecosystem
      and the entry to add.
- [ ] A fixture where an entry is removed, or where its directory no longer matches, makes it fail.
- [ ] Directories such as `node_modules`, `.git`, build outputs and the legacy `migration/` tree are not mistaken
      for manifests.
- [ ] `python-quality` triggers on a change of `.github/dependabot.yml` (push and pull request).
- [ ] `pytest`, `ruff check` and `ruff format --check` pass.

## Blocked by

- [01 — Declare the five dependency places](01-declare-ecosystems.md)
