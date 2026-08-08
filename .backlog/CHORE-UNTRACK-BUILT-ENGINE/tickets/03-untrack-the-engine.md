# 03 — Untrack the engine and say so

**Status:** todo
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

- [ ] A fresh clone has no `CTLD.lua`; `merge_CTLD.ps1` produces one; `git status` stays clean
      afterwards.
- [ ] CI is green with the file absent from the repository — in particular `python-quality` still
      reports 262 passed, 0 skipped.
- [ ] A release still attaches `CTLD.lua`, and so does the `dev` pre-release.
- [ ] EN and FR documentation in step.
