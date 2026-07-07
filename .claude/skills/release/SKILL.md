---
name: release
description: Consolidate a CTLD_Next release — draft community release notes from the CHANGELOG, bump the version, open a release PR, and guide the final tag. Use when the user wants to cut a release.
disable-model-invocation: true
---

# Release Consolidation Assistant

Interactive, step-by-step. **Wait for the user's confirmation at each step** — never run git
operations or push without an explicit go.

## Context

- Work branch: `develop`. Release branch: `release/x.y.z` (from `develop`).
- **PR target: `develop`** (not `master`; `master` is reserved for stable milestone merges).
- Version lives in `src/CTLD_config.lua` as `ctld.VERSION = "x.y.z"`; the build extracts it.
- The tag `published-vx.y.z` is pushed **manually by the user after merge** — pushing it triggers
  `.github/workflows/release.yml`, which rebuilds `CTLD_Next.lua` and publishes the GitHub Release.

## Steps

1. **Sync**: `git fetch` + `git pull --ff-only` on `develop`. Read the `[Unreleased]` section of
   `CHANGELOG.md`. Ask the user for the target version (propose a semver bump from the current
   `ctld.VERSION`).

2. **Consolidation interview** (3 questions):
   - Major theme of this release (one line)?
   - Any breaking changes or regressions mission makers must know about?
   - Contributors / highlights to credit?

3. **Draft `RELEASE_NOTES.md`** oriented at the **DCS community / mission makers**: features, fixes,
   and config/menu changes that affect them. **Filter out internal noise** (refactors, CI/tooling,
   test moves, backlog bookkeeping). Propose the draft and **wait for validation**.

4. **Apply** (after validation):
   - Write `RELEASE_NOTES.md`.
   - In `CHANGELOG.md`, replace `## [Unreleased]` with `## [x.y.z] — YYYY-MM-DD` (ask the user for
     the date or use today's).
   - Bump `ctld.VERSION` in `src/CTLD_config.lua` to `x.y.z`.
   - **Rebuild** the deliverable: `powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`
     (the version changed in `src/`).

5. **Git** (after the user's go): create `release/x.y.z` from `develop`, commit
   (`RELEASE_NOTES.md`, `CHANGELOG.md`, `src/CTLD_config.lua`, `CTLD_Next.lua`), push, open a PR
   targeting `develop`, report the URL. Wait for CI + review, then merge.

6. **Final tag** (give the user these commands to run after merge — pushing the tag is irreversible
   and triggers the release workflow):
   ```bash
   git checkout develop && git pull origin develop
   git tag published-vx.y.z
   git push origin published-vx.y.z   # ← triggers .github/workflows/release.yml
   ```
