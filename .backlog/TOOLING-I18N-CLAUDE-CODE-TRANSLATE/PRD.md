Status: ready

# TOOLING-I18N-CLAUDE-CODE-TRANSLATE — Claude Code CLI as a local i18n auto-translate fallback

Grilled with docs on 2026-08-10 (**ADR 0014**). Idea originated in `dev/roadmap.md` during
`FIX-I18N-DEBT-REPAYMENT`.

## Problem Statement

A CTLD contributor running `merge_CTLD.ps1` locally gets i18n stubs auto-translated only when
`ANTHROPIC_API_KEY` is set in their environment — a separate Anthropic Console key with its own
pay-as-you-go billing. A contributor who has a Claude Code subscription but never set up that
separate key gets no auto-translation at all: `translate_i18n.py` warns and exits, and every stub
stays empty until someone with a key runs the build. This happened concretely during
`FIX-I18N-DEBT-REPAYMENT` (2026-08-10): no `ANTHROPIC_API_KEY` was available, so 140 dictionary
entries were translated by hand instead of through the tool built for exactly that job.

## Solution

`tools/build/translate_i18n.py` gains a fallback translation backend: when `ANTHROPIC_API_KEY` is
absent, it shells out to the Claude Code CLI's non-interactive mode (`claude -p`) instead, which
authenticates via the Code subscription rather than a separate API key. The existing
`ANTHROPIC_API_KEY`-backed path is unchanged and stays first-priority — this adds a second way to
get auto-translation, it does not replace the first. `merge_CTLD.ps1`'s existing unconditional call
into `translate_i18n.py` needs no change: the script decides its own backend internally.

## User Stories

1. As a CTLD contributor with a Claude Code subscription but no `ANTHROPIC_API_KEY`, I want
   `merge_CTLD.ps1` to auto-translate new i18n stubs anyway, so I don't have to acquire a separate
   API key just to keep the KO/ES/FR dictionaries in sync with my `ctld.tr()` changes.
2. As a CTLD contributor who already has `ANTHROPIC_API_KEY` set, I want my existing workflow
   completely unchanged, so this lot introduces no regression or new failure mode for me.
3. As a contributor with neither an API key nor an authenticated Claude Code CLI, I want a single
   clear warning naming both ways to enable auto-translation, so I know what to do next instead of
   reading the script to discover there even is a second option.
4. As a maintainer, I want the CLI fallback to use the same cheap/fast model
   (`claude-haiku-4-5-20251001`) the API path already uses, so a bulk menu-string translation
   doesn't silently consume more of a contributor's Claude Code usage than a coding-oriented
   default model would.
5. As a maintainer, I want no pre-flight check for CLI/session availability, so the failure path
   stays a single, already-proven non-blocking `try/except`, not a second bespoke availability
   check to maintain.
6. As a CI maintainer, I want the `i18n-guard` job untouched, so this lot carries zero risk to the
   already-reviewed CI gate — it only ever inspects dictionary content, never how it was produced.
7. As a developer reading this code later, I want the reasoning recorded (dual mode over full
   replacement, no pre-check, pinned model, combined warning), so nobody "simplifies" it back to a
   single mechanism without understanding what that would break for API-key-less contributors.
8. As a developer touching the backend-selection logic later, I want it covered by a unit test, so
   a future change to the selection order (API vs. CLI vs. neither) doesn't silently regress.

## Implementation Decisions

- **Dual backend, API-key path unchanged and first-priority.** The existing
  `anthropic.Anthropic(api_key=...)` call and its batch-per-language flow are untouched. A new
  fallback path is only reached when `ANTHROPIC_API_KEY` is not set (or client initialization
  fails, matching current behavior).
- **CLI invocation**: `claude -p "<same JSON-in/JSON-out prompt already sent to the API>"
  --output-format json --model claude-haiku-4-5-20251001`, run as a subprocess. The response's
  `result` field is extracted and parsed with the same `json.loads()` already used for the API
  response — the prompt and downstream parsing/application logic (`_apply_translations`) are
  reused verbatim, only the call that produces the raw translation JSON changes.
- **Model pinned on the CLI call too**: `--model claude-haiku-4-5-20251001`, matching the API
  path's deliberate cheap/fast choice rather than inheriting the user's Claude Code session
  default (typically a heavier, coding-oriented model).
- **No pre-flight availability check.** The CLI backend is attempted directly; any failure (binary
  not on PATH, unauthenticated session, non-zero exit, malformed JSON) is caught by the same
  generic non-blocking exception handling the script already uses — consistent with its documented
  contract ("any error prints a WARNING and exits 0").
- **Combined warning when neither backend is available**: one message naming both
  `ANTHROPIC_API_KEY` and Claude Code CLI authentication as ways to enable auto-translation,
  replacing today's API-key-only warning text.
- **Backend selection is a small, pure, testable function**: given the environment/availability
  state, it decides which path to attempt (API key present → API; absent → try CLI; CLI also
  fails → combined warning, stubs stay empty). This is the one new piece of logic introduced by
  this lot.
- **`merge_CTLD.ps1` needs no change.** It already calls `translate_i18n.py` unconditionally when
  reachable; the backend choice is entirely internal to the Python script.
- **`i18n-guard` CI job needs no change** (ADR 0013, reaffirmed by ADR 0014): it inspects only
  dictionary diff content, never the mechanism that produced it, and CI auto-translation stays
  explicitly out of scope for both ADRs.

## Testing Decisions

- Tests target external behavior of pure functions, consistent with the rest of `tools/build/`'s
  test philosophy (`test_translate_i18n.py`, `test_i18n_dict_utils.py`).
- **New backend-selection function**: unit tested directly — cases: API key present (→ API
  backend chosen regardless of CLI availability); API key absent + CLI available (→ CLI backend);
  API key absent + CLI unavailable (→ neither, combined-warning case).
- **Not unit tested**: the actual subprocess call to `claude -p`, same as the existing API call
  (`_translate_batch`) is not mocked or unit tested today — verified manually instead. Introducing
  subprocess mocking here would be new test surface the rest of the file doesn't have, for a thin
  wrapper whose real value is only provable by an actual call.
- **Manual verification**: run `merge_CTLD.ps1` locally with `ANTHROPIC_API_KEY` unset but the
  `claude` CLI authenticated, confirm stubs get translated via the CLI path; run again with
  neither available, confirm the combined warning appears and stubs stay empty; run with the API
  key set, confirm existing behavior is bit-for-bit unchanged.
- Existing `pytest tools/build/` suite must stay green throughout — no behavior change to
  `_is_stub`, `_collect_stubs`, `_apply_translations`, or the shared parser.

## Out of Scope

- **The separate `-- STALE:` parsing gap** in `tools/build/i18n_dict_utils.py` (a live dictionary
  line and one commented out with `-- STALE:` match the same regex) — a distinct, already-existing
  bug unrelated to which translation backend is used. Tracked separately in `dev/roadmap.md`
  pending root-cause investigation (does `generate_i18n_dicts.ps1` mark `STALE` atomically across
  all four dictionaries, or independently per file?).
- **CI auto-translation.** Already rejected in ADR 0013 and reaffirmed here: no shared API key or
  write-capable token in CI, no Claude Code session available there either.
- **Any change to `merge_CTLD.ps1`, `generate_i18n_dicts.ps1`, `check_i18n_diff.py`, or the
  `i18n-guard` CI job.**
- **A pre-flight check for Claude Code CLI/session availability.** Deliberately rejected — see
  Implementation Decisions and ADR 0014.
- **Configurable model selection.** The pinned `claude-haiku-4-5-20251001` matches the existing
  API path; making it configurable is not requested and adds surface area without a stated need.

## Further Notes

- Full rationale and rejected alternatives: **ADR 0014**
  (`dev/adr/0014-i18n-claude-code-cli-fallback.md`).
- Prior art: `BUILD-DICT-AI-TRANSLATE` (PR #60, introduced `translate_i18n.py` and the
  local-only/`ANTHROPIC_API_KEY` decision this lot extends without reversing);
  `FIX-I18N-DICT-GUARD`/ADR 0013 (established that CI never auto-translates, reaffirmed here);
  `FIX-I18N-DEBT-REPAYMENT` (the lot whose lack of an API key surfaced this gap).
