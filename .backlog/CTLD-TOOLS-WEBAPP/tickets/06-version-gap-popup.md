# 06 — version-gap re-migration popup

Status: 📋 todo
Type: tool (frontend) + test

On opening a stale `configUser`, warn the MM that CTLD's version changed and present the diffs to
review before re-injecting (ADR 0011 point 5), driving lot-2's `version_gap` API.

- When a loaded catalogue's `configVersion` differs from the current default's, the backend returns
  the `version_gap` (added / removed / changed defaults); the frontend shows a **popup** listing
  them so the MM reviews before re-migrating. Never a silent merge.
- The MM decides per gap what to adopt; export/inject proceeds from the reconciled catalogue.
- Tests: the popup renders each gap category from a crafted stale-vs-current pair (reuses lot-2
  `version_gap` coverage; frontend asserts the three buckets surface).

Files: `ctld_tools/web/**`, `tools/ctld-tools/web/**`, `tests/**`. Depends on: 03.
