# 01 — Build the exe on every merge into `develop`

**Status:** todo
**Lot:** FEAT-DEV-BUILD-CHANNEL

## Problem

`build-exe` (`.github/workflows/release.yml:88`) only ever runs on a `published-v*` tag, so there is
nothing to hand a tester between two releases.

## Change

The same steps, triggered on a push to `develop`, in a workflow that blocks nothing (CI keeps its own
timings; this job just produces a file). Two publication paths, because they serve different people:

- **an action artifact**, traceable per run, for whoever has a GitHub account;
- **a floating `dev` pre-release**, rewritten on each merge, for everyone else: an artifact answers
  `401` to an anonymous download even on a public repository, and arrives as a `.zip` to unpack.

The tag driving the pre-release must **not** match `published-v*`, or it re-triggers the release
workflow. Its notes state in one line what the build is and what it is not: a build of `develop`, not
a release, with no documentation of its own.

## Acceptance

- [ ] A merge into `develop` produces both an artifact and an updated `dev` pre-release.
- [ ] The `dev` exe downloads **without a GitHub session** (the check that motivated the choice).
- [ ] Publishing a real release still works and does not collide with the floating tag.
