---
name: release
description: Consolidate a CTLD release — draft community release notes from the CHANGELOG, bump the version, open a release PR, and guide the final tag. Use when the user wants to cut a release.
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
  `.github/workflows/release.yml`, which rebuilds `CTLD.lua` and publishes the GitHub Release.
- **Pre-release channel**: a `-rc` suffix in the version (`x.y.z-rcN`) makes the CD publish a GitHub
  *pre-release* and leaves the floating `published-latest` tag on the previous stable. A plain
  `x.y.z` publishes a **stable** release and advances `published-latest` (the "last stable"
  download pointer).

## Steps

1. **Sync**: `git fetch` + `git pull --ff-only` on `develop`. Read the `[Unreleased]` section of
   `CHANGELOG.md`. Ask the user for the target version (propose a semver bump from the current
   `ctld.VERSION`, or an `x.y.z-rcN` pre-release when iterating toward an unreleased version).

2. **Consolidation interview** (3 questions):
   - Major theme of this release (one line)?
   - Any breaking changes or regressions mission makers must know about?
   - Contributors / highlights to credit?

3. **Draft `RELEASE_NOTES.md`** oriented at the **DCS community / mission makers**: features, fixes,
   and config/menu changes that affect them. **Filter out internal noise** (refactors, CI/tooling,
   test moves, backlog bookkeeping). Propose the draft and **wait for validation**.

   **The notes always open with an installation section, before anything else.** A release page lists
   several assets and a newcomer arriving from a forum link has to guess which one matters — the
   answer is `ctld-tools.exe` and nothing else. Two rules when adapting the template below: **name
   the exe as the only file needed** (the other assets belong to the manual path, one sentence
   lower), and **link, never duplicate** — the getting-started page is the long form, and a section
   that grows past a handful of lines becomes a second copy that will contradict the first.

   ```markdown
   ## Installation

   1. Téléchargez **`ctld-tools.exe`** ci-dessous — c'est le seul fichier dont vous avez besoin.
   2. Lancez-le : l'outil s'ouvre dans votre navigateur, en local, sans installation.
   3. Ouvrez votre `.miz`, réglez ce que vous voulez, puis **« Installer dans la mission »** : l'outil
      y écrit CTLD, les sons des balises et votre configuration.

   Vous préférez tout faire à la main ? Les fichiers sont aussi attachés à cette release — voir la
   [documentation](https://veaf.github.io/CTLD/).
   ```

   Once versioned documentation is published (`FEAT-TOOL-VERSION-AND-DOCS`), point that link at the
   released version rather than the site root.

4. **Apply** (after validation):
   - Write `RELEASE_NOTES.md`.
   - **CHANGELOG** — conditional on rc vs stable:
     - **Stable** (`x.y.z`): replace `## [Unreleased]` with `## [x.y.z] — YYYY-MM-DD` (ask the user
       for the date or use today's).
     - **Pre-release** (`x.y.z-rcN`): **leave `## [Unreleased]` open** so post-rc fixes keep landing
       there — do not freeze the changelog. (Optionally add a dated `## [x.y.z-rcN]` heading above
       `[Unreleased]` capturing the rc snapshot; the invariant is that `[Unreleased]` survives.)
   - Bump `ctld.VERSION` in `src/CTLD_config.lua` to the target (suffix included for an rc).
   - **Rebuild** the deliverable: `powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`
     (the version changed in `src/`).

5. **Git** (after the user's go): create `release/x.y.z` from `develop`, commit
   (`RELEASE_NOTES.md`, `CHANGELOG.md`, `src/CTLD_config.lua`, `CTLD.lua`), push, open a PR
   targeting `develop`, report the URL. Wait for CI + review, then merge.

6. **Final tag** (give the user these commands to run after merge — pushing the tag is irreversible
   and triggers the release workflow):
   ```bash
   git checkout develop && git pull origin develop
   git tag published-vx.y.z
   git push origin published-vx.y.z   # ← triggers .github/workflows/release.yml
   ```
