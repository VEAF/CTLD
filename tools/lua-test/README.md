# lua-test — run the unit specs locally, without busted

`busted` needs luarocks on Lua ≤ 5.4, which is awkward to install on a Windows dev box, so the
suite tends to run only in CI — several minutes of round-trip for a typo. This runner replays the
whole `tests/ci/unit/` suite in about a second, on **Lua 5.1**, the version DCS itself runs.

```powershell
powershell -ExecutionPolicy Bypass -File tools\lua-test\run_specs.ps1          # everything
powershell -ExecutionPolicy Bypass -File tools\lua-test\run_specs.ps1 beacon   # name filter
```

The wrapper looks for a Lua 5.1 interpreter, in this order: `$env:LUA51`,
`C:\Program Files (x86)\Lua\5.1\lua.exe` (LuaForWindows), then `lua5.1` / `lua` on the `PATH` —
accepting only one that reports `Lua 5.1`. Anything newer reports failures DCS would never see.
Without PowerShell, call the runner directly **from the repo root** (the specs use relative
`dofile` paths):

```bash
lua tools/lua-test/run_specs.lua ./ tests/ci/unit/beacon_spec.lua
```

## What it is, and is not

**CI's `busted` and `luacheck` remain the gate.** This is a fast local pre-check, not a second
source of truth. It implements `describe` / `context` / `it` / `before_each` / `after_each` /
`setup` / `teardown` and the `assert.*` subset the specs actually use (`equals`, `is_true`,
`is_false`, `is_nil`, `is_not_nil`, `same`, `has_no_error`, `is_truthy`, `not_equal`, the type
assertions) — nothing else.

So:

- a spec reaching for `spy`, `mock`, `stub` or a luassert matcher **fails here and passes in CI**.
  That is a runner limitation, not a regression;
- a spec that cannot even load is reported as `SKIP (runner limitation)` and the run continues;
- the specs run in one shared Lua state, sorted by filename, which is what reproduces the
  isolation bugs (a spec mutating shared singleton state without cleaning up) that only appear
  when the whole suite runs in order.

`dkjson_min.lua` is a minimal JSON decoder standing in for the `dkjson` rock. It exists for one
spec: `config_spec.lua`, which compares `CTLDConfig.parseYAML` against the committed oracle
`tests/ci/data/config_defaults.json`. That is the spec catching a setting added to
`src/CTLD_config.yaml` without regenerating the oracle:

```bash
poetry -C tools/ctld-tools run ctld-tools gen --yaml src/CTLD_config.yaml --out tests/ci/data/config_defaults.json
```

Skipping it locally would hide exactly the failure it is there to catch, which is why the
decoder is bundled rather than the spec skipped.

## Spec order, and how to check it

This runner executes the files **in the order you pass them**, and `run_specs.ps1` sorts them by
name. Busted does not: it walks `tests/ci/` and takes whatever order the filesystem gives, which on
Linux is a directory hash — arbitrary, and not stable between runs. So a fixed local order cannot,
on its own, tell you a spec is isolated.

Since the runner takes its file list as arguments, **run it backwards** and compare:

```bash
lua tools/lua-test/run_specs.lua ./ $(ls tests/ci/unit/*.lua | sort -r)
```

Forward and reverse must agree. They do today (1064 / 1064) — `FIX-SPEC-ISOLATION` closed a gap where
**29 tests failed in reverse**, all of them reading `capabilitiesByType` after `troop_manager_spec`
had set it to nil and walked away. Use `tests/ci/helpers/settings.lua` (`ctldTestSettings.borrow`) to
change a setting for the duration of a spec; it gives the previous value back, absent keys included.

Two traps that cost real time, worth knowing before you write the next fixture:

- **Restoring a setting is not enough if a singleton already consumed it.** `_processSpawnableCrates`
  stores what it read on `CTLDCrateManager`, so putting the setting back left the manager holding a
  catalogue built from test data. Drop the instance too.
- **`after_each` runs innermost-first** (busted's order, and this runner's since the same lot). Nested
  borrow/restore only nests correctly that way round — the inner block must give shared state back
  before the outer one restores what *it* borrowed.

## Checking the harness itself

A green run only means something if the harness can go red. Delete a key from
`tests/ci/data/config_defaults.json` and re-run: two specs must fail. Restore it afterwards.
