# 02 — `/api/inject` — `configOnly` field + sound-validation bypass

**Status:** ⬜ ready

**Blocked by:** ticket 01 (needs `install()`'s `configuration_only` parameter).

## What to build

`InjectRequest` gains an optional `configOnly: bool = False`. When true, the endpoint's pre-install
`validate()` call treats every sound setting as available for that call — a customised beacon
sound the session no longer holds bytes for must never block a configuration-only install, since
this mode never touches sound files at all. The endpoint then calls `install(...,
configuration_only=req.configOnly)`.

## Watch out

- The bypass is validation-only, scoped to the sound-availability findings — every other
  validation error (a genuinely broken setting, a missing crate unit, etc.) still blocks the
  install exactly as it does today, in both modes.
- Default behaviour (`configOnly` omitted or `false`) must be identical to today's `/api/inject` —
  every existing `test_web_app.py` inject test must keep passing unmodified.

## Acceptance

- Installing with `configOnly: true` succeeds even when a customised beacon sound's bytes are no
  longer held by the session (a case that would otherwise be flagged as missing).
- Installing with `configOnly: true` still fails validation on an unrelated real error (e.g. an
  unknown DCS unit type) — the bypass is scoped to sounds only.
- Installing with `configOnly` omitted (or `false`) behaves exactly as today: a missing customised
  sound's bytes still blocks the install.
- The resulting `install()` call receives `configuration_only=True` iff `configOnly` was true.

## Tests

`tools/ctld-tools/tests/test_web_app.py` (pytest), extending the existing `/api/inject` coverage:
a configuration-only install succeeds despite an unavailable customised sound; a full install
still fails on the same unavailable sound (regression-guarding the two modes' different
validation behaviour side by side); an unrelated validation error still blocks both modes.
