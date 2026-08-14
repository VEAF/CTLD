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

   **In English.** Release notes are a published deliverable and follow the repo rule (`CLAUDE.md`:
   deliverables in English). rc1 to rc3 shipped in French; that was a mistake, not a precedent — do
   not copy the previous file's language, and do not mix the two within a sentence.

   **The notes always open with an installation section, before anything else.** A release page lists
   several assets and a newcomer arriving from a forum link has to guess which one matters — the
   answer is `ctld-tools.exe` and nothing else. Two rules when adapting the template below: **name
   the exe as the only file needed** (the other assets belong to the manual path, one sentence
   lower), and **link, never duplicate** — the getting-started page is the long form, and a section
   that grows past a handful of lines becomes a second copy that will contradict the first.

   **The installation section also says what to do when Windows blocks the exe.** It is unsigned, so
   SmartScreen stops it on a first run — for a Mission Maker who has never seen this, "Windows
   protected your PC" reads as "this download is dangerous" and the release ends there. Three lines,
   no more; the mission-maker guide holds the long form.

   **Link the documentation of the version being released**, not the site root:
   `https://veaf.github.io/CTLD/<version>/mission-maker/` — every tag publishes its own copy
   (`FEAT-TOOL-VERSION-AND-DOCS`), so a reader landing on an old release page gets the pages that
   match it. There is deliberately **no `latest` alias yet**: it is created by the first *stable*
   release, and linking `/latest/` before that would be a dead link.

   ```markdown
   ## Installation

   1. Download **`ctld-tools.exe`** below — it is the only file you need.
   2. Run it: the tool opens in your browser, locally, with nothing to install.
   3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD,
      the beacon sounds and your configuration into it.

   **Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it:
   click **More info** → **Run anyway**. If the file came through a browser you may also need
   right-click → **Properties** → tick **Unblock** → **OK**.

   Prefer doing it by hand? The files are attached to this release too — see the
   [documentation](https://veaf.github.io/CTLD/<version>/mission-maker/).
   ```

4. **Apply** (after validation):
   - Write `RELEASE_NOTES.md`.
   - **CHANGELOG** — conditional on rc vs stable:
     - **Stable** (`x.y.z`): replace `## [Unreleased]` with `## [x.y.z] — YYYY-MM-DD` (ask the user
       for the date or use today's).
     - **Pre-release** (`x.y.z-rcN`): **leave `## [Unreleased]` open** so post-rc fixes keep landing
       there — do not freeze the changelog. (Optionally add a dated `## [x.y.z-rcN]` heading above
       `[Unreleased]` capturing the rc snapshot; the invariant is that `[Unreleased]` survives.)
   - Bump `ctld.VERSION` in `src/CTLD_config.lua` to the target (suffix included for an rc). This is
     the **only** version to bump: `ctld-tools` reads it as its single source of truth
     (`resources.py`), so the exe and its help link follow on their own. The `0.1.0` in
     `tools/ctld-tools/pyproject.toml` is a leftover and is not displayed anywhere.
   - **Rebuild** the deliverable: `powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`
     (the version changed in `src/`). This is a **local check**, not a file to commit — see step 5.
     Confirm the rebuilt `CTLD.lua` carries the new `ctld.VERSION` before going further.

5. **Git** (after the user's go): create `release/x.y.z` from `develop`, commit, push, open a PR
   targeting `develop`, report the URL. Wait for CI + review, then merge.

   - **Commit** `RELEASE_NOTES.md`, `src/CTLD_config.lua`, and `CHANGELOG.md` **only when step 4
     changed it** (a stable freeze, or an optional rc heading — an rc that leaves `[Unreleased]`
     alone has nothing to commit there).
   - **Never `CTLD.lua`.** It is a build artifact, git-ignored since `CHORE-UNTRACK-BUILT-ENGINE`
     (PR #110), and CI rebuilds it and attaches it to the release. `git add` on it silently does
     nothing; committing it was the pre-#110 instruction and is now wrong.
   - **PR title**: `release: prepare x.y.z` — the form every release PR has used since rc3.
   - **Label the PR `skip-changelog`.** Bumping `ctld.VERSION` is a `src/` change, so the
     `changelog-guard` CI job demands a `CHANGELOG.md` entry and fails the PR without it. Every
     release PR from rc3 to rc7 carried this label; a release is the one case where the guard has
     nothing to protect.

6. **Final tag** (give the user these commands to run after merge — pushing the tag is irreversible
   and triggers the release workflow):
   ```bash
   git checkout develop && git pull origin develop
   git tag published-vx.y.z
   git push origin published-vx.y.z   # ← triggers .github/workflows/release.yml
   ```
