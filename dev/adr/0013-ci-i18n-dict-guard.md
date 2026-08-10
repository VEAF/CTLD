# ADR 0013 — CI-enforced i18n dictionary guard, diff-scoped with a translation-only bypass

**Date:** 2026-08-10
**Status:** Accepted
**Lot:** FIX-I18N-DICT-GUARD (to be formalized via `to-prd`)

## Context

`ctld.tr()` keys are synchronised into the four dictionaries (`CTLD_i18n_en/fr/es/ko.lua`) by
`generate_i18n_dicts.ps1 -Apply`, run unconditionally by `merge_CTLD.ps1`. It appends missing keys
as empty stubs (`= ""` for non-EN) — it does not translate. The intended translation step,
`translate_i18n.py` (Claude Haiku, `BUILD-DICT-AI-TRANSLATE`, PR #60), only runs locally when
`ANTHROPIC_API_KEY` is set — a deliberate choice in that lot's PRD, absent from CI on purpose.

Two gaps let untranslated entries reach `develop` undetected:

1. **`translate_i18n.py`'s stub definition never matches what `generate_i18n_dicts.ps1` writes.**
   It treats a stub as "value identical to the EN text" (the original PRD's definition of
   "untranslated"), but new keys are appended as `""`, not a copy of the EN value. So even with
   `ANTHROPIC_API_KEY` set, freshly-added keys are never selected for translation.
2. **The only guard that exists (`.githooks/pre-push`) is opt-in** (`git config core.hooksPath
   .githooks`, a manual step after clone) and checks *only* for `MISSING` keys — an entry present
   with an empty value already satisfies it. It is not active by default; verified not active on
   the machine that surfaced this issue.

Consequence, verified against `develop` on 2026-08-10: 91 empty entries in `CTLD_i18n_ko.lua`, 76
in `CTLD_i18n_es.lua`. `CTLD_i18n_fr.lua` has none — filled by hand, not through the auto-translate
path, in `040bf8c`.

## Decision

**A new CI job, `i18n-guard`** (own job, PR-triggered, `ubuntu-latest` — ships `pwsh` natively, no
`windows-latest` needed), modeled on the existing `changelog-guard` job:

- **Blocks unconditionally** on any key `ctld.tr()`/the config YAML introduces that is `MISSING`
  from any of the four dictionaries. No bypass: fixing it costs a local `merge_CTLD.ps1` run, no
  API key required.
- **Blocks by default, bypassable via the `skip-i18n` label**, on any *newly introduced* non-EN
  entry that stays empty (`""`) — diff-scoped against the PR's base, the same technique
  `changelog-guard` uses. Scoped rather than absolute: an absolute check would fail every PR today
  against the 167 pre-existing empty entries.
- **`translate_i18n.py`'s stub detection is fixed** in the same lot to also treat `== ""` as a
  stub needing translation (not only `== EN value`) — the guard is only satisfiable locally if the
  tool it depends on actually works.
- **The 167 pre-existing empty entries are explicitly out of scope.** This guard only prevents new
  debt; repaying the existing debt is a separate, immediately-following lot (tracked outside this
  ADR).
- **`.githooks/pre-push` is left unchanged** (`MISSING`-only, non-blocking on stale/empty). CI is
  the single source of enforcement truth; the hook remains a best-effort local pre-check, not
  authoritative and not always active.

## Considered options

- **Auto-fix in CI** (a bot job runs `generate_i18n_dicts.ps1 -Apply` + `translate_i18n.py` and
  commits the result back to the PR branch). Rejected: requires `ANTHROPIC_API_KEY` as a shared
  GitHub secret and a token with write access to contributors' PR branches — reverses the
  deliberate "local-only, absent from CI" decision in `BUILD-DICT-AI-TRANSLATE`, and introduces
  bot-commit/re-trigger loops this repo doesn't otherwise have.
- **Absolute (non-diff) guard.** Rejected: would fail every PR immediately against the existing
  167-entry debt, coupling this lot to a full translation pass before it could ship at all.
- **No bypass label.** Rejected: the repo is public and `ANTHROPIC_API_KEY` is not guaranteed
  available to every contributor; a zero-tolerance guard would block legitimate external
  contributions on translation alone.
- **Extend the existing `build` job** instead of a new job. Rejected: `build` runs on
  `push`+`pull_request` generically and isn't scoped to a PR-base diff, and conflates artifact
  production with a content guard — the repo's existing pattern is one job per concern
  (`lua-lint`, `gitleaks`, `changelog-guard`).

## Consequences

- `skip-i18n` bypasses only the "must be non-empty" rule, never `MISSING` — so a bypassed PR can
  still land new empty stubs, growing the debt bucket the follow-up repayment lot has to cover.
  That lot must account for debt accrued after this guard ships, not only the 167 counted here.
- A developer only learns about untranslated debt at PR time (CI), not at `git push` time — the
  local hook was deliberately left MISSING-only rather than duplicating the diff-vs-base check in
  bash.
