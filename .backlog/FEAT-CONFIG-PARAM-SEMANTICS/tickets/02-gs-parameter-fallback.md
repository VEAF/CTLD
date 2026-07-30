# 02 — `ctld.gs()` resolves a missing parameter from the default, and says so

**Status:** ready

Depends on: 01 (the semantic must be written down first).

## Why

`CTLDConfig:load()` parses **only the winning document** ([CTLD_config.lua:34](../../../src/CTLD_config.lua#L34)),
so when a `configUser` is present the default is never available. A parameter the user config omits
therefore reads `nil`, and the three no-fallback sites turn that into a Lua error
([CTLD_jtac.lua:905](../../../src/CTLD_jtac.lua#L905), [CTLD_crate.lua:1503](../../../src/CTLD_crate.lua#L1503)).

## What changes

- Parse `ctld.configDefault` **lazily**: only on the first `gs()` miss, and only when a `configUser`
  was used. A complete config pays nothing, which is the normal case.
- In `ctld.gs(key)` / `getSetting`: when the key is absent from the loaded settings **and** its
  default value is a scalar, return the default and record the key. When the default is a list or a
  map, return `nil` as today — a missing collection is a removal, and the 46 `or {…}` call-site
  guards handle it.
- Collect the defaulted keys and emit **one** `ctld.startupReport` **NOTICE** at flush, listing them,
  in the same voice as the neighbouring fatal error ("Validate the snapshot with ctld-tools before
  use" — [CTLD_config.lua:54](../../../src/CTLD_config.lua#L54)). `NOTICE`, not `INFO`: a hand-written
  config never meets `validate`, so this is the MM's only signal.
- Do **not** change the existing hard error for a `configUser` that parses to nothing. An empty
  document stays fatal.

## Acceptance

- A config with `slingCutDestroyHeight` removed: mission loads, a crate release works, one NOTICE
  names the key.
- A config with `spawnableCrates` removed: no NOTICE, no crash, no crates — removal still works.
- A complete config: `configDefault` is never parsed, and no NOTICE is emitted.
- The NOTICE lists every defaulted parameter once, not one message per key.

## Tests

- busted: missing scalar → default returned + key recorded; missing collection → `nil`, not recorded.
- busted: the lase loop and the crate-release path survive a config missing their parameters
  (regression tests for the three known sites).
- busted: complete config → the lazy parse never runs (assert on a spy / parse counter).
