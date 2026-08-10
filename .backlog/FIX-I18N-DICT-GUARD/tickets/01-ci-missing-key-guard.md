Status: ready

# 01 — CI job `i18n-guard`: unconditional block on `MISSING`

## Parent

`.backlog/FIX-I18N-DICT-GUARD/PRD.md` (ADR 0013)

## What to build

A new CI job, `i18n-guard`, in `ci.yml`: PR-triggered only, `ubuntu-latest` (ships `pwsh`
natively), `fetch-depth: 0` checkout — same shape as the existing `changelog-guard` job.

For this ticket, the job runs a single check: it reuses `generate_i18n_dicts.ps1`'s existing
dry-run (no changes to that script) to detect any i18n key used in `src/` (via `ctld.tr()` or the
config YAML) that is missing from one or more of the four dictionaries
(`CTLD_i18n_en/fr/es/ko.lua`). If the dry-run output contains `MISSING`, the job fails. This check
has no bypass — it is always enforced, regardless of any PR label. `STALE` entries in the same
dry-run output are ignored by this job (non-blocking, same as the existing local
`.githooks/pre-push` hook).

This ticket only adds the job and this one check. The second check (new-empty-stub detection with
the `skip-i18n` bypass) is a separate ticket that extends this same job.

## Acceptance criteria

- [ ] `i18n-guard` job exists in `ci.yml`, triggered only on `pull_request` events.
- [ ] The job fails when a PR introduces a `ctld.tr()` key (or a config-YAML `desc`/`name` label)
      absent from any of the four dictionaries.
- [ ] The job passes when all keys used in `src/` exist in all four dictionaries, even if some
      non-EN values are empty (that check is out of scope for this ticket).
- [ ] `STALE` entries reported by the dry-run do not fail the job.
- [ ] Manually verified with a throwaway test PR: one that removes a dictionary entry still used
      by `src/` (fails), and one where the dictionaries are in sync (passes).

## Blocked by

None - can start immediately
