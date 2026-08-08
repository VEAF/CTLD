# 03 — Document the dev channel

**Status:** done
**Lot:** FEAT-DEV-BUILD-CHANNEL

## Problem

`DOCS-RELEASE-LIFECYCLE` has just told Mission Makers that a new CTLD only reaches them through a
published release. That stays true, and a second channel that nobody documents turns it into a
half-truth — "so where does this exe FullGas sent me come from?".

## Change

- **`docs/developer/workflow.md`** — the channel: what triggers it, where the exe lands, how it is
  versioned, and that it is not a release.
- **The mission-maker pages** keep saying releases, with one sentence acknowledging dev builds:
  unreleased, untested, and identified by the hash in their version — take one only if someone asks
  you to.
- **The `release` skill** unchanged: a dev build is not a release and gets no notes of its own.

## Acceptance

- [x] EN and FR in step, on both the developer and the mission-maker side (`workflow.{md,fr.md}`,
      `ctld-tools.{md,fr.md}`).
- [x] No wording that suggests a dev build supersedes a release: both pages open on "a release is
      the only thing you are told to download", and the mission-maker sentence says to take a dev
      build only when asked.
