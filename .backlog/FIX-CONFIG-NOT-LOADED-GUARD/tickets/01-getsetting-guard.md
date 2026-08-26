# 01 — refuse `getSetting` before `ctld.initialize()`, with a clear message

**Status:** ✅ done

See the PRD for the legacy-parity-free root cause and the reasoning behind the chosen guard site.

## What changes

1. `src/CTLD_config.lua`, `CTLDConfig:getSetting` (~line 106): at the top, before reading
   `self.settings[key]`, add:
   ```lua
   if not self.isLoaded then
       error("CTLD configuration is not loaded — call ctld.initialize() before reading any "
           .. "CTLD setting or using a CTLD manager.", 0)
   end
   ```
2. `src/CTLD_config.lua`, `CTLDConfig:load()`: the malformed-`configUser` validation must run
   before `self.isLoaded` is set to `true` — otherwise an aborted load leaves the guard above
   bypassed (settings stay empty, but `isLoaded` already reads `true`).
3. `CHANGELOG.md` `[Unreleased]`: a **Fixed** entry.

## Watch out

- **Do not touch `CTLD_i18n.lua`.** Its existing `pcall` around `ctld.gs("i18n_lang")`
  (`_activeLang()`, ~line 71) already tolerates a pre-init call and falls back to
  `ctld.i18n_lang or "en"`. Verify (don't just assume) that this fallback still fires unchanged
  once the guard is in place — the `pcall` should catch the new explicit `error()` exactly as it
  caught the old implicit `nil`-arithmetic crash.
- **Do not add a guard to any manager's `getInstance()`.** The single `getSetting` guard is
  deliberately meant to replace that approach entirely, not complement it.
- The `error()` level is `0` (message only, no position) — a fixed non-zero level was tried first
  but breaks for real tail-call sites (`return ctld.gs(key)` in `CTLD_aasystem.lua` and
  `CTLD_troop.lua`), which drop the caller's stack frame in Lua 5.1 and leave the error
  positionless or mis-pointed. The message text alone is the diagnosis.
- `CTLDConfig.get()` itself must not be touched — it still lazily creates the singleton with
  `isLoaded = false`. The guard only changes what `getSetting` does once that instance exists.

## Acceptance

- `CTLDConfig.get():getSetting("anything")` on a fresh (never-`:load()`-ed) instance raises an
  error whose message names `ctld.initialize()`.
- `ctld.gs("anything")` on a fresh instance raises the same error.
- `getSetting` still refuses (no silent `nil`) after a `load()` call that aborted on a malformed
  `ctld.configUser` — the guard isn't bypassed by `isLoaded` being set before validation.
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
