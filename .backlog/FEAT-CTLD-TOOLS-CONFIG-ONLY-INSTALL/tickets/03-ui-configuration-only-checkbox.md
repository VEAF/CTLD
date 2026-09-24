# 03 — UI: "Configuration only" checkbox

**Status:** ⬜ ready

**Blocked by:** ticket 02 (needs the `configOnly` field on `/api/inject`).

## What to build

A checkbox next to the existing "Install into mission…" button, unchecked by default, with a
tooltip naming the concrete scenario (a mission whose engine already loads some other way — e.g.
a dev-local mechanism, or a Mission Maker managing `CTLD.lua` separately). Checking it and clicking
install sends `configOnly: true` to `/api/inject`.

## Watch out

- Unchecked (the default) must reproduce today's install flow exactly — no behaviour change for
  the normal one-click case.
- The install-outcome message (`web.outcome.injected` etc.) should still make sense in this mode —
  it already reports what `InstallResult.files`/`triggers` list, which ticket 01 already scopes
  correctly to "configuration only" in that mode; no new message wording is required unless the
  existing one reads oddly with an empty engine/sounds list (check before adding one).

## Acceptance

- The checkbox exists, is unchecked by default, and its tooltip names the use case.
- Clicking "Install into mission…" with it unchecked sends the same request shape as today
  (`configOnly` absent or `false`).
- Clicking it with the checkbox checked sends `configOnly: true`.

## Tests

`web/src/App.test.ts` (vitest + testing-library/svelte), extending the existing install-flow
coverage (`installing reports what landed in the mission`, `injection is blocked while the config
has errors`): the checkbox's default state; checking it changes the `/api/inject` request body to
include `configOnly: true`; unchecked leaves the request unchanged from today's.
