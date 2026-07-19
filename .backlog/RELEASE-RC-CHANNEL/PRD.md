# Lot RELEASE-RC-CHANNEL — add a pre-release (rc) channel + `published-latest` floating tag to the CD

Status: ✅ done
Branch: chore/release-rc-channel → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)
ADRs: none (CI/release tooling)

## Problem Statement

CTLD's release CD (`.github/workflows/release.yml`) is a **minimal tag-driven** publisher: pushing a
`published-vX.Y.Z` tag builds `CTLD.lua` (+ companion + userConfig) and creates a GitHub Release.
It has **no notion of a pre-release channel** and **no floating "latest stable" pointer**.

To ship **2.0.0** cleanly we want to cut a **`2.0.0-rc1`** first, iterate, then promote to stable —
without the rc being served to production users as "the latest release".

VMCT (the re-tooling reference) runs the **same tag-driven model** as us — verified: its
`release.yml` triggers only on `published-v*`, its release command targets `develop-v6` with a
manual tag, `master` is reserved for stable milestones and no workflow releases on a branch push.
The difference is two mechanics VMCT's `release.yml` adds that ours lacks:

1. **Pre-release detection from the tag suffix**: a semver pre-release suffix (`-rc1`, a `-` in the
   version) publishes the GitHub Release as a *pre-release*.
2. **A floating `published-latest` tag**: advanced **only** by a real (non-pre-release) release, so
   production users tracking `published-latest` stay on the last stable when an rc ships.

This lot ports those two mechanics into our CD. It does **not** change the trigger model (still
tag-driven; `master` stays un-outillé for release, same as VMCT).

## Solution

Extend `release.yml` and the `release` skill so a `-rc`-suffixed version publishes a **pre-release**
and leaves `published-latest` untouched, while a plain `x.y.z` publishes a **stable** release and
advances `published-latest`.

## User Stories

- As a **maintainer**, I want to cut `2.0.0-rc1` as a GitHub *pre-release* so testers can grab it
  without it becoming the default "Latest" download for everyone.
- As a **mission maker**, I want a stable **`published-latest`** URL that always points at the last
  stable `CTLD.lua`, so I can pin a download link that never serves an rc.
- As a **maintainer**, I want the `release` skill to handle an rc bump (keep `[Unreleased]` open)
  vs a stable bump (freeze the changelog), so the two flows don't require remembering the difference.

## Implementation Decisions

- **(a) Adopt `published-latest`** — a floating tag advanced only by a stable release; a permanent
  "latest stable `CTLD.lua`" download pointer. Not touched by a pre-release.
- **(b) Pre-release detection = version suffix** — a `-` in the version (`2.0.0-rc1`) marks a
  pre-release (`gh release create --prerelease`), mirroring VMCT's `*-*` test. A plain `x.y.z` is
  stable.
- **(c) CHANGELOG on an rc stays open** — an rc does **not** convert `## [Unreleased]`; only a stable
  release rewrites it to `## [x.y.z] — YYYY-MM-DD`. Post-rc fixes keep landing under `[Unreleased]`.
- **(d) Scope = tooling only** — this lot delivers the CD + skill changes. Actually cutting
  `2.0.0-rc1` is a **separate follow-up step** using the improved skill.
- Trigger model unchanged (tag-driven `published-v*`); no branch-driven release, no `master`
  automation — consistent with VMCT.
- Files: `.github/workflows/release.yml` (rc detection, `--prerelease`, `published-latest` step) and
  `.claude/skills/release/SKILL.md` (rc-aware bump + conditional CHANGELOG).

## Testing Decisions

- `release.yml` is CI YAML, not busted-testable. Validate the rc-detection shell logic locally
  (`2.0.0-rc1` → prerelease, `2.0.0` → stable) the way `changelog-guard` was validated.
- End-to-end proof is the follow-up `2.0.0-rc1` cut, out of this lot's scope.
- No `src/` change, no rebuild.

## Out of Scope

- **Cutting the actual `2.0.0-rc1` / `2.0.0` release** — a follow-up step once this tooling lands.
- **Branch-driven CD** (release on push to `develop`/`master`) — VMCT doesn't do it either; rejected.
- **Multi-OS binaries / an updater** — VMCT-specific (PyInstaller); N/A for our single `CTLD.lua`.
- A published `docs/` page for the release process — the skill is the process doc; a `published-latest`
  download-link mention in user docs can be a later touch (noted below).

## Further Notes

- **`published-latest` in user docs**: once the tag exists, a "always-latest-stable" download link
  could be surfaced on a pilot/mission-maker download page — deferred, not required for the tooling.
- **Proposed ticket split** (tracer-bullet):
  1. `01` — `release.yml`: rc detection + `--prerelease` + `published-latest` floating-tag step.
  2. `02` — `release` skill: rc-aware version bump + conditional `[Unreleased]` freeze.
