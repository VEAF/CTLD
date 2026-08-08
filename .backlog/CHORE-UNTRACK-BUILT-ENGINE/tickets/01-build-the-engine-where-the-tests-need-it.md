# 01 — Build the engine in the job that tests it

**Status:** done
**Lot:** CHORE-UNTRACK-BUILT-ENGINE

## Problem

`python-quality` (`.github/workflows/python-quality.yml`) runs on ubuntu and never builds
`CTLD.lua`; 27 tests currently run only because the file is committed. This must be fixed **before**
the file goes away, or the deletion turns a green pipeline into a lie.

`merge_CTLD.ps1` is the single source of truth for the build and must stay so — no second, simpler
"build for tests" path that could drift from it.

## Change

Make the script run on the ubuntu image and call it before `pytest`. Two path expressions are the
only Windows-only things in it:

- line 25 — `Join-Path $scriptDir "..\.."`
- line 33 — `Join-Path $repoRoot "tools\ctld-tools"`

`Join-Path` composes with the platform separator; a literal `\` inside the argument does not. Both
become `Join-Path` chains (or `/`, which Windows accepts too).

If `pwsh` turns out to be absent from the ubuntu image, the fallback decided during the grilling is
to move the job to `windows-latest` — same steps, about two minutes more, free on a public
repository. Do not invent a third build path.

## What was done

Three literal Windows paths, not two: `generate_i18n_dicts.ps1:36` carries the same `"..\.."`, and
`merge_CTLD.ps1` calls it, so it had to go too. All three are now composed one segment at a time.

`python-quality` gained a `pwsh` step running `merge_CTLD.ps1` before `pytest`, and its `paths:`
filter now includes `src/**` and `tools/build/**` — the job builds the engine, so a change to
either can break it and must trigger it.

## Acceptance

- [x] `python-quality` builds `CTLD.lua` before running `pytest`.
- [x] A local Windows build still works unchanged — same command, and `git diff` on the rebuilt
      `CTLD.lua` reports no changed line. Suite still at **262 passed**.
- [ ] The suite reports **262 passed, 0 skipped** on the ubuntu runner — only observable once this
      PR's CI runs. It is also where `pwsh`'s presence on the image gets confirmed; the fallback if
      it is missing is `windows-latest`, per the ticket.
