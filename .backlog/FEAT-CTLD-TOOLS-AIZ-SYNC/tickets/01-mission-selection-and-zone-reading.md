# 01 — Mission selection (relaxed) + zone-name reading endpoint

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

A new entry point (button reusing the existing native picker, `dialogs.pick_miz`) that sets
`session.mission_path` directly, and a new backend endpoint that reads the tracked mission's
`env.mission.triggers.zones` (via `miz.read_mission()`, already used for injection) and returns
every zone name.

## Watch out

- **`Session.load_path()` is not the right hook.** Today it's the only way `mission_path` gets
  set, and it raises when the target `.miz` has no CTLD configuration already installed
  (`install.read_config()` fails) — exactly the case for a dev/test mission that only loads the
  engine via `CTLD_DEV_ROOT` and has never been through `ctld-tools install`. This ticket's new
  entry point must set `mission_path` **without** requiring an installed configuration — it is a
  second way to set the same field, not a relaxation of `load_path()` itself (don't change what
  `load_path()` requires for its own, existing purpose of also loading a configuration).
- `mission_path` keeps its single meaning across the app (per the grill: one mission notion, not
  two) — this ticket does not introduce a separate "zone source" concept.
- The zone-reading endpoint reads the **raw** trigger-zone list — it does not filter, parse, or
  interpret names in any way. That's tickets 03/04's job.

## Acceptance

- Clicking the new "choose mission" action opens the native `.miz` picker (same dialog already
  used elsewhere in the app) and, on a valid selection, updates `session.mission_path` — even for
  a `.miz` with no CTLD configuration installed in it yet.
- A new endpoint returns the full list of trigger-zone names from the currently tracked mission.
- Calling the endpoint with no mission selected yet returns a clear, handled response (not an
  unhandled exception).

## Tests

`tools/ctld-tools/tests/test_miz.py` (pytest): round-trip a generated mission fixture through the
new zone-listing capability, same style as the existing `inject_userconfig` tests already there.
