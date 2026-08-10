Status: ready

# 01 — Claude Code CLI fallback for i18n auto-translation

## Parent

`.backlog/TOOLING-I18N-CLAUDE-CODE-TRANSLATE/PRD.md` (ADR 0014)

## What to build

Add a second translation backend to `tools/build/translate_i18n.py`: when `ANTHROPIC_API_KEY` is
absent (or Anthropic client initialization fails, matching current behavior), fall back to the
Claude Code CLI's non-interactive mode instead of giving up.

A small, pure backend-selection function decides which path to use: API key present → API backend
(unchanged, first-priority); API key absent → attempt the CLI backend; CLI also unavailable/fails
→ neither, stubs stay empty.

The CLI backend shells out to `claude -p` with the same JSON-in/JSON-out prompt already sent to
the API, pinning the model (`claude-haiku-4-5-20251001`, matching the API path's deliberate
cheap/fast choice) and requesting structured JSON output so the response can be parsed the same
way the API response already is (`json.loads()` on the extracted result text). Downstream handling
— matching translations back to stubs, writing them into the dictionary file via
`_apply_translations` — is reused unchanged; only the call that produces the raw translation JSON
differs between the two backends.

No pre-flight check for CLI/session availability: the call is attempted directly, and any failure
(binary not found, unauthenticated session, non-zero exit, malformed JSON) is caught by the same
generic non-blocking exception handling the API path already uses. When neither backend is
available, a single combined warning names both `ANTHROPIC_API_KEY` and Claude Code CLI
authentication as ways to enable auto-translation.

`merge_CTLD.ps1` needs no change — it already calls `translate_i18n.py` unconditionally when
reachable, and the backend choice is entirely internal to the script. The `i18n-guard` CI job
needs no change either — it only inspects dictionary diff content, never the mechanism that
produced it.

## Acceptance criteria

- [ ] A pure backend-selection function exists and is unit tested: API key present → API backend
      chosen (CLI never attempted); API key absent + CLI available → CLI backend chosen; API key
      absent + CLI unavailable → neither, combined-warning case.
- [ ] With `ANTHROPIC_API_KEY` set, script behavior is unchanged bit-for-bit from today (API path
      untouched).
- [ ] With `ANTHROPIC_API_KEY` unset and the `claude` CLI authenticated, running the script
      translates stubs via the CLI backend, pinning `--model claude-haiku-4-5-20251001`.
- [ ] With `ANTHROPIC_API_KEY` unset and the `claude` CLI unavailable/unauthenticated, the script
      prints one combined warning naming both `ANTHROPIC_API_KEY` and `claude` CLI authentication,
      and exits 0 with stubs left empty (no crash, matching the script's non-blocking contract).
- [ ] The CLI backend call itself is not unit-tested/mocked — verified manually only, matching the
      existing precedent for the API call (`_translate_batch`).
- [ ] No change to `merge_CTLD.ps1`, `generate_i18n_dicts.ps1`, `check_i18n_diff.py`, or the
      `i18n-guard` CI job.
- [ ] `pytest tools/build/` stays green — no behavior change to `_is_stub`, `_collect_stubs`,
      `_apply_translations`, or the shared parser.
- [ ] Manually verified: all three scenarios above run for real against a live dictionary with at
      least one empty stub, confirming the correct backend is used and the dictionary file ends up
      correctly translated (CLI case) or unchanged (neither-available case).

## Blocked by

None - can start immediately
