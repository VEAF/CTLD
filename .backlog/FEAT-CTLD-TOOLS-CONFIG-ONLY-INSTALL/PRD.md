# FEAT-CTLD-TOOLS-CONFIG-ONLY-INSTALL — a configuration-only install mode in `ctld-tools`

**Status:** ✅ done (PR #174).

Formalizes `dev/roadmap.md`'s "`ctld-tools` — mode « configuration seule » à l'installation (évite
le double chargement moteur)" entry (added 2026-09-24), surfaced while widening
`FEAT-EXZ-AUTODISCOVERY` ticket 01 from 3 to all 15 `AIZ_` zones actually present in
`missions/Test_CTLDNEXT_01.miz`. This PRD does not re-derive the problem — it formalizes it and
resolves the two open decision points the roadmap entry left unresolved.

This is a `ctld-tools` (Python/FastAPI backend + Svelte frontend, `tools/ctld-tools/`) feature. No
`src/` (Lua engine) change is in scope.

## Problem Statement

A Mission Maker (or developer) whose mission already loads the CTLD engine through a mechanism
`ctld-tools` doesn't own — a separately-managed `CTLD.lua`, or (the concrete case that surfaced
this) the project's own dev/test mission's `CTLD_DEV_ROOT` env-var trigger (`DEV-LOCAL-MIZ`),
always loading the freshest local build — has no way to install *only* the CTLD configuration
through `ctld-tools`. The app's single "Install into mission…" button always writes the engine and
the beacon sounds alongside the configuration, each as its own resource-keyed file and MISSION
START trigger. Using it on such a mission doesn't replace or conflict with the existing
engine-loading trigger — `ctld-tools`' own trigger placement renumbers every trigger it doesn't
own rather than touching it — so the mission ends up with **two** engine-loading paths at once: a
real risk of the engine initializing twice (duplicate manager singletons, duplicate event-handler
registration), not a cosmetic redundancy.

## Solution

Add a configuration-only install mode: a checkbox next to the existing "Install into mission…"
button, unchecked by default (today's one-click behaviour — the normal case of a Mission Maker who
wants `ctld-tools` to manage the engine too — is unchanged). When checked, only the configuration
trigger, file and `mapResource` entry are written; the engine and beacon-sound triggers/files are
skipped entirely, and whatever already loads the engine in that mission is left completely
untouched.

## User Stories

1. As a developer whose test mission loads the engine through its own dev-local mechanism
   (`CTLD_DEV_ROOT`), I want to install just the configuration through `ctld-tools`, so that I
   never end up with two competing engine-loading triggers in the same mission.
2. As a Mission Maker who manages their own `CTLD.lua` deployment separately from `ctld-tools` (for
   example, distributing it through a server's own mod pack), I want the same configuration-only
   option, so that `ctld-tools` never overwrites or duplicates a file I control myself.
3. As a Mission Maker doing the normal one-click install, I want the default behaviour to stay
   exactly as it is today (engine + sounds + configuration together), so that this new option never
   adds a step to the common case.
4. As a Mission Maker who customised a beacon sound, I want a configuration-only install to never
   block on "the tool no longer holds that sound's bytes", so that a validation concern about a
   file this install isn't touching at all doesn't stop me from installing my configuration.
5. As a Mission Maker who previously did a full install and later switches to configuration-only on
   the same mission, I want the earlier engine and sound triggers removed, so that the mission
   actually ends up with only what "configuration only" promises — not a full install plus a
   redundant partial one.
6. As a developer reading the install report after a configuration-only install, I want it to list
   only what was actually written (the configuration), so that the UI's confirmation message never
   claims an engine or sound install that didn't happen.
7. As a developer running `test_install.py`, I want configuration-only covered by the same test
   file and style as every other `install()` behaviour, so that a regression in this mode is caught
   the same way as any other.

## Implementation Decisions

- **New parameter on `install()`**: a single boolean, `configuration_only` (default `False`) —
  not independent engine/sounds toggles. The one concrete use case (a mission with its own
  engine-loading mechanism) needs both skipped together; nothing today asks for skipping just one
  of the two, and adding that granularity now would be speculative.
- **What gets skipped**: when `configuration_only` is true, `install()` builds and writes only the
  configuration trigger/file/`mapResource` entry — the engine file, the engine trigger, every
  beacon-sound file and the sounds trigger are never constructed or written.
- **Sound-availability validation is bypassed in this mode.** The existing pre-install `validate()`
  call can flag a customised beacon sound as "missing" when the tool no longer holds its bytes —
  a real concern for a full install, a false alarm for one that never touches sounds at all.
  Decision: when the install request is configuration-only, treat every sound setting as
  available for that validation call, so a stale/missing custom-sound reference never blocks a
  configuration-only install.
- **Re-install idempotency across modes, resolved**: a configuration-only install always removes
  any engine/sound triggers a *previous* install (full or otherwise) left in that mission —
  in addition to replacing its own configuration trigger, it passes the engine and sound markers
  into the same idempotent-removal set the trigger rebuild already uses. Rationale: the checkbox's
  promise is that `ctld-tools` will not manage the engine in that mission; leaving a stale
  engine-loading trigger behind after switching modes would silently break that promise and
  reintroduce the exact double-load risk this feature exists to prevent. The reverse direction
  (switching from configuration-only back to a full install) already converges correctly today,
  because a full install already rebuilds all three trigger kinds together.
- **API contract**: `POST /api/inject`'s request body gains an optional `configOnly` (default
  `false`); when true, the endpoint's pre-install validation uses the sound-bypass above and the
  call into `install()` passes `configuration_only=True`.
- **Install report**: its `files` and `triggers` lists reflect only what was actually written
  (configuration alone in this mode), so the UI's "Installed into `<mission>`" confirmation never
  overclaims.
- **UI**: a checkbox beside the existing "Install into mission…" button, unchecked by default, with
  a tooltip naming the concrete scenario (a mission whose engine already loads some other way).

## Testing Decisions

- `tools/ctld-tools/tests/test_install.py` is the existing seam for `install()` itself — extend it
  with configuration-only cases, matching its existing style (e.g. `test_the_report_says_what_was_
  written`, `test_installing_twice_replaces_and_does_not_accumulate`): only the configuration
  trigger/file/resource-map entry is written; a pre-existing unrelated trigger survives untouched
  (same guarantee the existing suite already asserts for a full install); a configuration-only
  re-install after a prior full install removes the earlier engine/sound triggers; the report lists
  only the configuration.
- `tools/ctld-tools/tests/test_web_app.py` is the existing seam for `/api/inject` — extend it for
  the `configOnly` request field, and for the sound-validation bypass (a customised sound the
  session no longer holds bytes for does not block a configuration-only install, but still blocks
  a full one — regression-guarding the two modes' different validation behaviour side by side).
- Only external behaviour is asserted (what's in the resulting `.miz`, what the report says, what
  validation returns), not `install()`'s internal control flow — matching this file's existing
  style throughout.

## Out of Scope

- Any change to the default (full) install behaviour for the normal Mission Maker case.
- `CTLD_DEV_ROOT` / `DEV-LOCAL-MIZ` itself — untouched by this lot.
- Independent engine-only or sounds-only toggles — only the single combined
  "configuration-only" mode described above.
- `FEAT-EXZ-AUTODISCOVERY` ticket 01's own 15-zone parameter table — already written, unrelated to
  this mechanism (this lot is what makes actually *applying* that table to
  `Test_CTLDNEXT_01.miz` possible without a double engine load, nothing more).

## Further Notes

- No ADR: the shape here (one boolean flag, symmetric marker cleanup) is a straightforward
  extension of the existing install/trigger-rebuild mechanism, not a new architectural decision
  with real alternatives weighed against each other.
- Once this lands, resuming `FEAT-EXZ-AUTODISCOVERY` ticket 01 means: a.lingo confirms the 5
  still-open `aiDropMode` values in that ticket's table, enters all 15 zones via `ctld-tools`'
  `AiZonesEditor`, then installs into `Test_CTLDNEXT_01.miz` with the new configuration-only
  checkbox checked.
