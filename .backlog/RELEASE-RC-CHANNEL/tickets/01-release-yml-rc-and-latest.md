# 01 — release.yml: pre-release detection + published-latest floating tag

Status: ✅ done
Type: AFK
Repo: CTLD
GitHub: —

## What to build

Extend `.github/workflows/release.yml` (triggered by `published-v*` tags) with VMCT's two mechanics.

1. **Pre-release detection** from the tag/version. In the existing "Resolve version from tag" step,
   also compute a `prerelease` flag: a `-` in the version (e.g. `2.0.0-rc1`) → `prerelease=true`,
   else `false`. Emit it via `$GITHUB_OUTPUT`.
2. **`--prerelease` on the GitHub Release**: pass `--prerelease` to `gh release create` when
   `prerelease=true`, so an rc is published as a GitHub *pre-release* (not the default "Latest").
   Keep the existing assets (`CTLD.lua`, `dist/CTLD_userConfig.lua`, `dist/CTLD_asset_check.lua`) and
   the `RELEASE_NOTES.md`-or-`--generate-notes` logic.
3. **Advance `published-latest`** only on a stable release: add a step, conditioned on
   `prerelease != 'true'`, that force-moves a floating `published-latest` tag to the released commit
   and pushes it:
   ```bash
   git tag -f published-latest "$TAG"
   git push origin -f published-latest
   ```
   (The job already has `permissions: contents: write`.) A pre-release leaves `published-latest`
   on the previous stable.

Keep everything else (Windows runner, build steps, companion build) unchanged. Trigger stays
`on: push: tags: ['published-v*']`.

Note: pushing `published-latest` will itself match `published-v*`? No — `published-latest` does not
match `published-v*` (no version digits after `-v`), so it does not re-trigger the workflow. Confirm
this in the PR description.

## Acceptance criteria

- [ ] Version step emits `prerelease=true` for a `-`-suffixed version, `false` otherwise.
- [ ] `gh release create` gets `--prerelease` iff `prerelease=true`; assets + notes unchanged.
- [ ] A stable release force-moves and pushes `published-latest`; a pre-release does **not**.
- [ ] `published-latest` does not re-trigger the release workflow (not matched by `published-v*`).
- [ ] rc-detection shell logic validated locally (`2.0.0-rc1` → prerelease, `2.0.0` → stable).
- [ ] YAML parses clean.

## Blocked by

None. Independent of ticket 02.
