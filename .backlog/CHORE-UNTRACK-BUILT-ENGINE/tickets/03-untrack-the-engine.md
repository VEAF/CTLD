# 03 — Untrack the engine and say so

**Status:** done
**Lot:** CHORE-UNTRACK-BUILT-ENGINE

## Problem

With tickets 01 and 02 in, nothing depends on the committed `CTLD.lua` any more. It remains as a
one-megabyte generated diff in almost every code PR (26 of 28 merges over 30 days), a guaranteed
conflict between parallel branches, and a file that can silently disagree with `src/` if someone
forgets to rebuild.

## Change

- `git rm --cached CTLD.lua`, and `.gitignore` gains the file — replacing the line that currently
  explains why it is *not* ignored. The new comment states the real reason it can go: releases and
  the `dev` pre-release both attach it (`FEAT-DEV-BUILD-CHANNEL`).
- **`CLAUDE.md`** — "rebuild after any `src/` change" becomes explicit that the rebuild is for
  testing and is not committed.
- **`docs/developer/building-and-testing.{md,fr.md}`** — where the built engine comes from for a
  contributor (build it), for a Mission Maker (the tool, or a release asset), and for a tester
  (the `dev` pre-release).

No history rewriting: the 471 past blobs weigh 2.8 MiB packed and harm nobody.

## Acceptance

- [x] The file is untracked (`git ls-files CTLD.lua` → nothing) and ignored
      (`git check-ignore` → `/CTLD.lua`), so a fresh clone has none and a local build leaves
      `git status` clean.
- [x] EN and FR documentation in step: `building-and-testing.{md,fr.md}` gain a table saying where
      to get an engine per role, and `CLAUDE.md` now says *never commit* as well as *never
      hand-edit*.
- [x] A release still attaches `CTLD.lua`, and so does the `dev` pre-release — observed on the
      first dev build: assets `ctld-tools.exe` (22.4 MB) and `CTLD.lua` (1.17 MB), the latter
      declaring `ctld.VERSION = "2.0.0-rc6-182ec25"`.
- [x] CI green with the file absent from the repository: all eight checks pass on PR #110, and
      `python-quality` reports **262 passed, 0 skipped** after building the engine itself.
