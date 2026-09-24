# 01 — Core `install()` — `configuration_only` mode

**Status:** ⬜ ready

**Blocked by:** none — can start immediately.

## What to build

A new `configuration_only: bool = False` parameter on `install()`. When `True`, only the
configuration trigger, file and `mapResource` entry are constructed and written — the engine file,
engine trigger, every beacon-sound file and the sounds trigger are never built at all. In addition
to writing its own configuration trigger, a configuration-only install removes any engine/sound
triggers a *previous* install (of either mode) left in the mission — pass the engine and sound
markers into the same idempotent-removal set the trigger rebuild already uses, even though this
call writes no new triggers for them.

`InstallReport.files`/`triggers` must reflect only what was actually written in this mode
(configuration alone) — never claim an engine or sound install that didn't happen.

## Watch out

- The reverse direction (a configuration-only mission later getting a full install) already works
  correctly today — a full install already rebuilds all three trigger kinds together. Don't add
  special-case logic for that direction; only the configuration-only path needs the extra
  marker-cleanup step.
- Default behaviour (`configuration_only=False`) must be byte-for-byte identical to today's
  `install()` — no caller passes the new parameter yet, so every existing test must keep passing
  unmodified.
- This ticket is Python-only (`install()` itself) — no API/UI wiring. `/api/inject` and the
  Svelte checkbox are tickets 02/03.

## Acceptance

- `configuration_only=True` writes only the configuration trigger/file/resource-map entry; no
  engine file, no sound files, no engine/sounds triggers appear in the resulting `.miz`.
- A mission that previously got a full install, then a configuration-only re-install, ends up with
  only the configuration trigger — the earlier engine and sound triggers are gone.
- A pre-existing, unrelated trigger (not one of `ctld-tools`' own) survives a configuration-only
  install untouched, same guarantee the existing suite already asserts for a full install.
- The report's `files`/`triggers` list only the configuration in this mode.
- Every existing `test_install.py` test (default, full-install behaviour) still passes unmodified.

## Tests

`tools/ctld-tools/tests/test_install.py` (pytest), extending the existing style (e.g.
`test_the_report_says_what_was_written`, `test_installing_twice_replaces_and_does_not_accumulate`):
configuration-only writes only the configuration; a full-then-configuration-only re-install cleans
up the earlier engine/sound triggers; an unrelated existing trigger survives; the report reflects
only the configuration in this mode.
