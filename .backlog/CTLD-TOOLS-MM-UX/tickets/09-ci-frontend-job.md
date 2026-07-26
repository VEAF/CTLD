# 09 — CI job for the web app

**Status:** done

## Why

Found while working the lot: **no CI job runs the frontend suite.** `CTLD-TOOLS-WEBAPP` shipped
vitest tests and a `npm run check` script, but `ci.yml` has no Node job at all, and `release.yml`
only runs `npm run build` — a build succeeds with red tests. So the frontend tests have never gated
anything, and this lot adds ~40 more of them.

The exe bundles this frontend, so a regression here reaches Mission Makers directly.

## Work

New `frontend` job in `.github/workflows/ci.yml` (ubuntu, Node 22, npm cache keyed on
`tools/ctld-tools/web/package-lock.json`):

1. `npm ci`
2. `npm run check` — svelte-check + tsc
3. `npm test` — vitest
4. `npm run build` — proves the bundle the exe ships still builds

## Done when

- The job appears in CI and is green on this branch.
