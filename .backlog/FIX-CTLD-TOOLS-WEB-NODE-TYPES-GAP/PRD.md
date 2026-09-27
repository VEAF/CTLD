# FIX-CTLD-TOOLS-WEB-NODE-TYPES-GAP — declare Node ambient types for `ctld-tools`' web app type-check

**Status:** 🔄 in-progress (ticket 01 done; ticket 02 pending merge).

Formalizes investigation into [Dependabot PR #193](https://github.com/VEAF/CTLD/pull/193)
("ci: bump @vitest/mocker and vitest in /tools/ctld-tools/web") and
[Dependabot PR #194](https://github.com/VEAF/CTLD/pull/194) ("ci: bump vitest from 3.2.7 to
5.0.1 in /tools/ctld-tools/web"), both opened 2026-09-24 and both failing CI's **"Web App
(ctld-tools)"** check identically. The two PRs carry the same underlying `package.json`/
`package-lock.json` diff (`vitest` `^3.2.0` → `^5.0.1`, `@vitest/mocker` along for the ride as a
transitive dependency) — #193 is Dependabot's grouped-update PR, #194 its individual-update PR for
the same dependency, opened in parallel by a grouping-rule overlap.

## Problem Statement

Bumping `vitest` from 3.2.0 to 5.0.1 in `tools/ctld-tools/web` breaks `svelte-check` with 10 new
TypeScript errors, all in `src/lib/i18n.parity.test.ts`: `Cannot find module 'node:fs'`, `Cannot
find module 'node:path'`, `Cannot find name 'process'`, `Cannot find name 'global'`. This blocks
CI (`Web App (ctld-tools)` job, part of `npm run check`) on both Dependabot PRs, even though
`@types/node` is already declared as a devDependency (`^24.13.2`) — so the failure is not a
missing package.

Root cause, confirmed locally (`npx svelte-check --tsconfig ./tsconfig.app.json` passes with 0
errors against the currently-committed `vitest@3.2.0`): `tsconfig.app.json`'s `compilerOptions.types`
is `["svelte", "vite/client"]` — it never lists `"node"`, so `@types/node`'s ambient globals
(`process`, `global`, the `node:*` module augmentations) are not supposed to be visible to any file
`svelte-check` compiles under that config, including `i18n.parity.test.ts` (which sits under
`src/lib/`, in scope for `tsconfig.app.json`, not `tsconfig.node.json`, which does declare
`"types": ["node"]` correctly for `vite.config.ts`).

It works today only by accident: `vitest@3.2.0`'s own public `.d.ts` graph (`vitest/dist/index.d.ts`
→ `chunks/reporters.d.*.d.ts` and `chunks/worker.d.*.d.ts`) imports value bindings from `node:*`
modules, which pulls `@types/node`'s ambient global declarations into the whole TypeScript program
as a side effect of type-checking the `vitest` import itself — independently of what
`tsconfig.app.json` declares. `vitest@5.0.1` restructured its internal dependency graph (new
`es-module-lexer` dependency, `chai` 5 → 6, `debug` replaced by `obug`, etc.), and the top-level
`vitest` module's public type surface no longer reaches a `node:*` import on that path — so the
incidental leak disappears, and the test file's real, previously-undeclared dependency on Node's
ambient types surfaces as genuine errors. The bump is not the bug; it removes an accidental prop
the config was always missing.

## Solution

Declare `"node"` explicitly in `tsconfig.app.json`'s `compilerOptions.types`, so
`i18n.parity.test.ts` (and any future test file under `src/`) resolves Node's ambient types on
purpose rather than by accident of `vitest`'s internal import graph. Then land the `vitest`/
`@vitest/mocker` version bump for real (same end state Dependabot's two PRs are after), confirm
`npm run check` and `npm test` are both green locally and in CI, and close #193/#194 as superseded.

## User Stories

1. As a `ctld-tools` maintainer, I want `svelte-check` to pass on a routine `vitest` version bump,
   so that a devDependency update doesn't block on an unrelated, pre-existing type-config gap.
2. As a `ctld-tools` maintainer, I want `tsconfig.app.json` to declare every ambient type surface a
   file under `src/` genuinely uses, so that whether a test file's `node:fs`/`process`/`global`
   usage resolves doesn't depend on which transitive `.d.ts` file `vitest` happens to import that
   month.
3. As a `ctld-tools` maintainer reviewing CI, I want the two duplicate Dependabot PRs (#193, #194)
   resolved by one fix instead of merged/investigated separately, so that the same root cause isn't
   diagnosed twice.
4. As a future contributor adding a new `src/lib/*.test.ts` file that reads a fixture file or
   inspects `process.cwd()` (the same pattern `i18n.parity.test.ts` already uses), I want that to
   type-check without needing to discover this same accidental-leak history first.

## Implementation Decisions

- **`tsconfig.app.json` gains `"node"` in `compilerOptions.types`** (today `["svelte",
  "vite/client"]` → `["svelte", "vite/client", "node"]`). Scoped to the whole `tsconfig.app.json`
  (which covers all of `src/**/*.ts` / `*.js` / `*.svelte`), not a separate tsconfig carved out just
  for test files: `i18n.parity.test.ts` already lives alongside ordinary app code under `src/lib/`,
  there is no existing test-only tsconfig to extend, and introducing one for a single file's
  `node:fs`/`node:path`/`process` usage is more machinery than the problem warrants.
- **`vitest` bumped to `^5.0.1` in `tools/ctld-tools/web/package.json`**, `package-lock.json`
  regenerated (`@vitest/mocker` and the rest of the transitive graph follow automatically) — the
  same end state #193/#194 already propose, landed here instead so the config fix and the bump are
  verified together rather than the fix racing a separately-merged Dependabot PR.
- **No `src/` (Lua) change** — this lot is confined to `tools/ctld-tools/web/`. No `CTLD.lua`
  rebuild required, no CHANGELOG entry needed for the Lua engine (the PR still updates
  `CHANGELOG.md` `[Unreleased]` per the tooling change itself, or carries `skip-changelog` if the
  maintainer judges a tooling-only devDependency bump doesn't warrant a user-facing entry).
- **#193 and #194 are closed as superseded** once this lot's PR merges, with a comment pointing to
  it — Dependabot will stop proposing the now-satisfied version bump on its own, but closing them
  explicitly avoids two dangling PRs lingering in the "why are these still open" state that
  triggered this investigation.

## Testing Decisions

- The regression proof **is** the existing CI seam: `npm run check` (`svelte-check --tsconfig
  ./tsconfig.app.json && tsc -p tsconfig.node.json`), already gated in CI as the "Web App
  (ctld-tools)" job. No new test file is warranted — this is a type-config fix, not new application
  behavior; the correct check is "the command that was red is now green," confirmed both locally
  and by CI on the PR.
- `npm test` (`vitest run`) is also run locally against the bumped `vitest@5.0.1` to confirm
  `i18n.parity.test.ts` and the rest of the suite still pass under the new major version, not just
  that they type-check.
- No `tools/ctld-tools/tests/` (pytest) impact — this lot touches only the web app's TS tooling
  config and its `vitest` devDependency, nothing in the Python backend.

## Out of Scope

- Auditing `vitest@5.0.1` for other, non-type-checking breaking changes beyond what's needed to get
  `npm run check` and `npm test` green (e.g. config-shape changes, reporter API changes) — fixed
  only if the green-CI verification in this lot actually surfaces one.
- Reviewing `tsconfig.node.json` or any other tsconfig in the project for the same class of
  accidental-leak risk — it already declares `"types": ["node"]` correctly. A broader "audit every
  tsconfig for undeclared ambient-type reliance" idea, if wanted, belongs in `dev/roadmap.md` as its
  own future candidate, not built here.
- Any change to `i18n.parity.test.ts` itself — its use of `node:fs`/`node:path`/`process` is
  legitimate and unchanged; only its type resolution was ever broken.

## Further Notes

No ADR needed — this is a tooling type-config fix, not a domain or architectural decision, and
`CONTEXT.md` is not touched.
