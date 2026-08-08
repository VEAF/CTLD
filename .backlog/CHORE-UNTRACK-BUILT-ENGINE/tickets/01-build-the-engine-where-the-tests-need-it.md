# 01 — Build the engine in the job that tests it

**Status:** todo
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

## Acceptance

- [ ] `python-quality` builds `CTLD.lua` before running `pytest`.
- [ ] The suite reports **262 passed, 0 skipped** in CI (the number to beat: today's ubuntu run
      passes 262 only because the artifact is committed).
- [ ] A local Windows build still works unchanged — same command, same output byte for byte.
