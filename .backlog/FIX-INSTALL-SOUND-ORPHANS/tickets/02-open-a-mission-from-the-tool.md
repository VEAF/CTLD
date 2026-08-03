# 02 — Let the open dialog list missions

**Status:** done
**Lot:** FIX-INSTALL-SOUND-ORPHANS

## Problem

Reported by Zip: "comment je charge mes configs CTLD à partir d'un .miz ? y'a pas de bouton !"

There is no missing endpoint. `Session.load_path` routes on the extension and reads a mission's
configuration in both storage shapes (rc4's file, rc1–rc3's inline), and `/api/inject` writes back to
the mission it came from. What was missing is the way in:

- `dialogs.open_config()` filtered on `*.yaml *.yml`, so the native picker listed no mission;
- the button read "Open a config **file**…", which states the opposite of what the tool can do.

Reachable only by switching the picker to "All files" — undiscoverable. The gap survived the lot that
introduced the capability because the native dialog is interactive and never exercised in CI.

## Change

- `OPEN_FILETYPES`: default entry "CTLD config or mission" (`*.yaml *.yml *.miz`), then the narrower
  ones. One default covering both, because reopening a configuration is one task whether it sits in a
  `.yaml` or in the `.miz` it was installed into.
- Button renamed to "Open config or mission…" / "Ouvrir une config ou une mission…" — in the two tool
  locales **and** the frontend's own EN dictionary, which a parity test compares.
- Documented in the mission-maker pages (EN + FR): reopening the mission is the normal way to resume.

## Verification

- `test_open_dialog_offers_missions` — asserts the filter passed to the dialog, since the dialog
  itself cannot run in CI.
- `App.test.ts` targets the button by its new accessible name.
