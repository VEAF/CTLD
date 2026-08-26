# 01 — refuse `getSetting` before `ctld.initialize()`, with a clear message

**Status:** ⬜ ready

See the PRD for the legacy-parity-free root cause and the reasoning behind the chosen guard site.

## What changes

1. `src/CTLD_config.lua`, `CTLDConfig:getSetting` (~line 106): at the top, before reading
   `self.settings[key]`, add:
   ```lua
   if not self.isLoaded then
       error("CTLD configuration is not loaded — call ctld.initialize() before reading any "
           .. "CTLD setting or using a CTLD manager.", 3)
   end
   ```
2. `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- **Do not touch `CTLD_i18n.lua`.** Its existing `pcall` around `ctld.gs("i18n_lang")`
  (`_activeLang()`, ~line 71) already tolerates a pre-init call and falls back to
  `ctld.i18n_lang or "en"`. Verify (don't just assume) that this fallback still fires unchanged
  once the guard is in place — the `pcall` should catch the new explicit `error()` exactly as it
  caught the old implicit `nil`-arithmetic crash.
- **Do not add a guard to any manager's `getInstance()`.** The single `getSetting` guard is
  deliberately meant to replace that approach entirely, not complement it.
- The `error()` level is `3`, not the default `1` — verify this actually points the stack at the
  real caller of `ctld.gs(...)` (e.g. a line in `CTLD_zone.lua`), not at the line inside
  `getSetting` itself or inside `ctld.gs`.
- `CTLDConfig.get()` itself must not be touched — it still lazily creates the singleton with
  `isLoaded = false`. The guard only changes what `getSetting` does once that instance exists.

## Acceptance

- `CTLDConfig.get():getSetting("anything")` on a fresh (never-`:load()`-ed) instance raises an
  error whose message names `ctld.initialize()`.
- `ctld.gs("anything")` on a fresh instance raises the same error, with the traceback pointing at
  the caller's own line, not at `CTLD_config.lua`.
- After `CTLDConfig:load()` runs, both behave exactly as before — no change to loaded-state
  behavior.
- `ctld.tr(...)` called before `CTLDConfig` is loaded still returns a translated (or "en"-default)
  string, never raises — confirms `CTLD_i18n.lua`'s pcall-based tolerance is unaffected.
- `busted tests/ci/` green, `luacheck --config .luacheckrc src/` clean, `CTLD.lua` rebuilt.

## Tests

Extend `tests/ci/unit/config_spec.lua` — it already has the exact seam needed: its `before_each`
does `CTLDConfig._instance = nil; cfg = CTLDConfig.get(); cfg:load()`. Add a new `describe`
block that does the same reset **without** calling `:load()`, then:

- `getSetting("anyKey")` raises an error containing `"ctld.initialize()"`.
- `ctld.gs("anyKey")` raises the same error.
- After calling `cfg:load()` inside that same test, a subsequent `getSetting`/`ctld.gs` call
  succeeds normally (no lingering guard state).

Add one case to whichever i18n spec already covers `ctld.tr()` (or a nearby existing test) proving
a pre-load `tr()` call still returns a string rather than raising — regression coverage for the
`CTLD_i18n.lua:71` pcall site.
