# 02 — Build job calls `merge_CTLD.ps1` (single source of truth)

Status: ⬜ ready
Type: AFK

## What to build

Replace the inline PowerShell merge re-implementation in the build job with a direct call to
`tools/build/merge_CTLD.ps1`, and upload the resulting `CTLD.lua` as an artifact. Eliminate
the duplicated merge logic so there is one canonical way to produce the deliverable.

## Acceptance criteria

- [ ] The build job runs `tools/build/merge_CTLD.ps1` (Windows runner).
- [ ] `CTLD.lua` is uploaded as a build artifact.
- [ ] The inline merge duplicate is deleted from the workflow.
- [ ] Artifact is byte-identical (UTF-8 without BOM) to a local `merge_CTLD.ps1` run.

## Blocked by

None - can start immediately.
