# RELEASE

**Status:** delivered. Compacted from `RELEASE/` on 2026-08-01; the ticket files live on in git history.

`release` skill + `release.yml` (tag `published-v*`); release job moved out of ci.yml (PR #7).

## Tickets

| Ticket | Status | Title |
|---|---|---|

## PRD

## Lot RELEASE — release process (skill + workflow)

Status: ✅ done
Branch: feature/release → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

### Problem Statement

There is no consolidated release process. The inherited `release` job in `ci.yml` fired on `v*`
tags with an auto-generated one-line note and lived inside the CI workflow. Nothing helps a
maintainer turn the `[Unreleased]` CHANGELOG into community-facing release notes, bump the version,
and cut a tagged release in a repeatable way.

### Solution

- An interactive **`release` skill** that consolidates the `[Unreleased]` CHANGELOG into
  community-oriented `RELEASE_NOTES.md`, bumps `ctld.VERSION`, rebuilds the deliverable, and opens a
  `release/x.y.z` PR targeting `develop`.
- A dedicated **`release.yml`** workflow triggered by the `published-v*` tag that rebuilds
  `CTLD.lua` and publishes a GitHub Release (attaching the deliverable, using `RELEASE_NOTES.md`
  when present).

### Scope

- `.claude/skills/release/SKILL.md` — the interactive assistant (user-invocable; side effects).
- `.github/workflows/release.yml` — tag `published-v*` → rebuild + `gh release create`.
- `.github/workflows/ci.yml` — remove the old `release` job and the `v*` tag trigger (moved out).

### Testing Decisions

- The release workflow is verified by its first real tag push (no cheap dry-run in CI). `ci.yml`
  keeps passing on `develop`/PR after the release job removal (no functional job lost — release is
  now its own workflow).

### Out of Scope

- Publishing to any registry other than GitHub Releases.
- `master` promotion / stable-milestone flow (PRs target `develop`).

### Further Notes

Version convention: `ctld.VERSION = "x.y.z"` in `src/CTLD_config.lua`; tag `published-vx.y.z`. The
tag is pushed manually after merge (irreversible; triggers the release workflow).
