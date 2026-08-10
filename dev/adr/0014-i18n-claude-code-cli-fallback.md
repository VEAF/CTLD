# ADR 0014 — i18n auto-translate: Claude Code CLI as a local fallback, not a replacement

**Date:** 2026-08-10
**Status:** Accepted
**Lot:** TOOLING-I18N-CLAUDE-CODE-TRANSLATE (to be formalized via `to-prd`)

## Context

`tools/build/translate_i18n.py` fills empty i18n stubs via the Anthropic API
(`anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])`), called automatically by
`merge_CTLD.ps1` whenever that key is set — a deliberate local-only mechanism
(`BUILD-DICT-AI-TRANSLATE`, preserved by `FIX-I18N-DICT-GUARD`/ADR 0013). A contributor with a
Claude Code subscription but no separate `ANTHROPIC_API_KEY` (its own pay-as-you-go billing,
distinct from the Code subscription) gets no auto-translation at all — lived concretely during
`FIX-I18N-DEBT-REPAYMENT` (2026-08-10), where the maintainer translated 140 entries by hand for
want of a key.

Claude Code's non-interactive mode (`claude -p "prompt" --output-format json --model <id>`)
authenticates via the Code subscription instead, and can drive the same JSON-in/JSON-out prompt
`translate_i18n.py` already sends.

## Decision

**Dual mode, not a replacement.** The existing API-key path stays first-priority and unchanged
(already tested, already the documented mechanism); when `ANTHROPIC_API_KEY` is absent, the script
falls back to shelling out to `claude -p`, pinning `--model claude-haiku-4-5-20251001` — the same
deliberate cheap/fast model choice the API path makes, rather than inheriting whatever heavier
default model the user's Code session is configured with.

- **No pre-flight availability check.** The CLI call is attempted directly; any failure (binary
  absent, session unauthenticated, malformed output) is absorbed by the same generic
  non-blocking `try/except` the script already uses for the API path — consistent with its
  documented contract ("any error prints a WARNING and exits 0").
- **Combined warning when neither path is available**, naming both `ANTHROPIC_API_KEY` and `claude`
  authentication as ways to enable auto-translation, rather than two separate messages that only
  mention the path just attempted.
- **CI is unaffected and stays out of scope**, exactly as ADR 0013 already decided: the `i18n-guard`
  job only inspects dictionary content, never how it was produced, so it needs no change either way.
- **Not tested by mocking the subprocess call** — matches the existing precedent: `_translate_batch`
  (the API call) has never been unit-tested either, verified manually instead. The backend-selection
  logic (API key present → API; absent → try CLI; neither → warn) is a pure function and is tested.

## Considered options

- **Replace the API path entirely with the CLI.** Rejected: would force every existing
  `ANTHROPIC_API_KEY` user (the tested, working path) onto a session-dependent mechanism for no
  benefit to them, and lose fine-grained model control in the general case.
- **Pre-check CLI/session availability before attempting translation** (e.g. `claude --version`).
  Rejected: adds a second failure-handling path for a check that buys little — Claude Code already
  fails fast and clearly when unauthenticated, caught by the same generic handler.
- **Let the CLI call use the session's default model.** Rejected: a coding-oriented default model
  is typically heavier than needed for batch menu-string translation, and would spend more of the
  user's subscription usage than the deliberately cheap model the API path already chose.

## Consequences

- The i18n auto-translate mechanism now has two independent failure modes to reason about
  (API error vs. CLI error) sharing one combined warning message — slightly less precise
  diagnostics in exchange for one fallback path instead of a hard stop.
- A future contributor wondering "why shell out to a CLI instead of just using the SDK
  everywhere?" has this record instead of reverse-engineering the reasoning from the diff.
