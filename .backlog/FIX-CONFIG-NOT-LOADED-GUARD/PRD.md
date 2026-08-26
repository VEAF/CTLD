# FIX-CONFIG-NOT-LOADED-GUARD — reading config before ctld.initialize() crashes unreadably

**Status:** ✅ done

Reported by **David "Zip" Pierron** ([GitHub issue #125](https://github.com/VEAF/CTLD/issues/125)),
found on CTLD `2.0.0-rc7` vendored in VEAF-Mission-Creation-Tools, where the integrator failed to
call `ctld.initialize()`. Grilled 2026-08-26.

## The deviation

Any code that reads a CTLD setting before `ctld.initialize()` has run gets `nil` back silently,
then usually crashes on ordinary arithmetic a few lines later — with a stack trace that names
neither CTLD nor the missing initialization.

Confirmed: `CTLDConfig:getSetting` ([CTLD_config.lua:106-114](../../src/CTLD_config.lua#L106))
reads `self.settings[key]` (an empty `{}` until `CTLDConfig:load()` runs) then
`self._defaults[key]` (also unpopulated pre-load), returning `nil` unconditionally before
`ctld.initialize()`. `ctld.gs` ([:305-307](../../src/CTLD_config.lua#L305)) is documented as "the
ONLY authorised form to read config parameters throughout `src/`" and delegates straight to
`getSetting` — every one of the 18 singleton managers' `getInstance()` → `init()` sequence reads a
setting this way, so the *first* manager touched in that state is the one that crashes. The
reported case: `CTLDZoneManager.getInstance()` → `init()` → `_scheduleSmoke()`
([CTLD_zone.lua:1075-1140](../../src/CTLD_zone.lua#L1075)) reads `smokeRefreshInterval`, gets
`nil`, then `timer.getTime() + interval` throws an unreadable arithmetic error.

## What changes

- `CTLDConfig:getSetting`: refuse at the top when `not self.isLoaded`, with
  `error("CTLD configuration is not loaded — call ctld.initialize() before reading any CTLD
  setting or using a CTLD manager.", 0)`. Chosen over the issue's own suggestion (a guard in each
  manager's `getInstance()`, ~18 call sites) or a guard in `ctld.gs`: `getSetting` is the deepest
  single choke point for *config reads* — it catches every read reached through `ctld.gs` (the
  sole path any `src/` code takes) *and* the documented-but-unused direct
  `CTLDConfig.get():getSetting(...)` API a mission script could call. It does not cover a manager
  whose `init()` never reads a setting (e.g. `CTLDSceneManager`): building one pre-init still
  succeeds silently, and the crash is only deferred to whichever setting is actually read
  downstream — an accepted gap, not a regression, since the issue's own crash was itself a config
  read. Level `0` on `error()` (message only, no position): several real callers reach `getSetting`
  via a tail call (`return ctld.gs(key)`), which in Lua 5.1 drops the caller's own stack frame — a
  fixed level would then land wrong, sometimes on a frame with no line info at all. The message
  text naming `ctld.initialize()` is the actual diagnosis; a stack position was found unreliable
  enough to drop.
- **No change to `CTLD_i18n.lua`.** `_activeLang()` ([:70-73](../../src/CTLD_i18n.lua#L70)) already
  wraps its `ctld.gs("i18n_lang")` call in `pcall`, specifically to tolerate a pre-init `tr()`
  call, falling back to `ctld.i18n_lang or "en"`. Confirmed this fix doesn't regress it: the
  `pcall` catches the new explicit error exactly as it already caught the old implicit one
  (`ok=false` either way), so the fallback still fires unchanged.
- No new config setting, no new manager guard, no changes to `getInstance()` anywhere.
- `CHANGELOG.md`: a **Fixed** entry.

## Definition of done

- Reading any CTLD setting (via `ctld.gs` or `CTLDConfig.get():getSetting()` directly) before
  `ctld.initialize()` raises a clear error naming `ctld.initialize()`, instead of crashing later
  on arithmetic.
- `CTLD_i18n.lua`'s pre-init `tr()` tolerance is unaffected — still falls back silently, no crash.
- `busted tests/ci/` green.
- No migration note: nothing for a mission maker to do. An integrator who already calls
  `ctld.initialize()` correctly sees no change; one who doesn't now gets a diagnosis instead of a
  crash in the dark.

## Out of scope

- Adding a guard to any manager's `getInstance()` — superseded by the single `getSetting` choke
  point, which covers the same ground without 18 call sites to keep in sync.
- Any change to `CTLD_i18n.lua`'s existing pcall-based tolerance — confirmed compatible as-is, no
  reason to touch it.
- A fallback default for `smokeRefreshInterval` (the issue's own alternative, explicitly
  rejected): would let a whole unconfigured engine run on implicit defaults, silently — worse than
  a clear refusal.

## Further Notes

- No ADR: a defensive guard at an already-identified sole choke point, not a new mechanism or a
  surprising trade-off — the "why" fits in the error message and a short code comment.
- Direct precedent for the "refuse early at the one real entry point rather than patch each
  symptom" reasoning: `FIX-BEACON-FM-POOL-GAP`'s own choice to fix `_buildFreqPools` at its root
  rather than patch every caller.
