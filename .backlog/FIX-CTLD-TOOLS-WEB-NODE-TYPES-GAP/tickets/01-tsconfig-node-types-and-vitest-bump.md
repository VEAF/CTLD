# 01 — Declare Node types in `tsconfig.app.json` and land the `vitest` 5.0.1 bump

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

Add `"node"` to `tsconfig.app.json`'s `compilerOptions.types` (today `["svelte", "vite/client"]`),
so `@types/node`'s ambient globals (`process`, `global`, `node:*` module augmentations) are
declared on purpose for every file under `src/` — including `src/lib/i18n.parity.test.ts`, which
already uses `node:fs`/`node:path`/`process` legitimately but only type-checked today by accident
of `vitest@3.2.0`'s own internal `.d.ts` import graph.

Then bump `vitest` to `^5.0.1` in `tools/ctld-tools/web/package.json` (the same version
Dependabot PR #193/#194 already propose) and regenerate `package-lock.json` so
`@vitest/mocker` and the rest of the transitive graph follow.

Verify both `npm run check` (`svelte-check --tsconfig ./tsconfig.app.json && tsc -p
tsconfig.node.json`) and `npm test` (`vitest run`) pass locally after the bump, then push and
confirm the "Web App (ctld-tools)" CI job goes green on the PR.

## Watch out

- `@types/node` is already a devDependency (`^24.13.2`) — this is not a missing-package problem,
  only a missing `types` declaration. Don't add or change the `@types/node` version.
- `tsconfig.node.json` already declares `"types": ["node"]` correctly for `vite.config.ts` — leave
  it untouched.
- Confirm locally (before touching anything) that `npx svelte-check --tsconfig
  ./tsconfig.app.json` currently passes with 0 errors against the committed `vitest@3.2.0`, so the
  before/after contrast is real and not assumed.
- No `src/` (Lua) change is in scope here — don't touch anything outside
  `tools/ctld-tools/web/`.
- If bumping to `vitest@5.0.1` surfaces any other break beyond the type-check (a config-shape or
  reporter API change), fix only what's needed to get `npm run check`/`npm test` green — a wider
  `vitest@5` migration audit is out of scope for this lot.

## Acceptance

- `tsconfig.app.json`'s `compilerOptions.types` includes `"node"`.
- `tools/ctld-tools/web/package.json` declares `vitest` `^5.0.1`; `package-lock.json` is
  regenerated to match.
- `npm run check` passes with 0 errors, including on `src/lib/i18n.parity.test.ts`.
- `npm test` passes.
- CI's "Web App (ctld-tools)" job is green on the PR built from this ticket.

## Tests

No new test file — the regression proof is the existing CI seam itself (`npm run check` /
`npm test`, already gated as the "Web App (ctld-tools)" job): confirm it is red before the
`tsconfig.app.json` fix (bump alone) and green after (fix + bump together).
