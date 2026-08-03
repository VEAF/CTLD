# 01 — a spec that mutates a shared setting restores it

**Status:** done — reverse-order run went from **29 failures to 0**, and the starting point turned out
to be worse than the PRD's count suggested: three distinct leaks, only one of which was a plain
missing `after_each`.

## What changes

- `troop_manager_spec` and `type_collector_spec`: capture the settings they touch and restore them in
  an `after_each`, including on failure. Same treatment for `CTLDTroopManager._instance` and any
  other singleton they null out.
- Prefer a tiny helper over nine hand-written save/restore pairs, e.g. a `withSetting(key, value)`
  used by `before_each`, so the next spec does the right thing by construction rather than by
  discipline.

## Proving it, cheaply

The local runner takes its file list as arguments, so a reversed run is one command:

```bash
lua tools/lua-test/run_specs.lua ./ $(ls tests/ci/unit/*.lua | sort -r)
```

Forward and reverse must agree. Any spec that only passes in one direction is another leak — fix it
or record it in this ticket. This is the check to run **before** touching anything, so the starting
point is known.

## Watch out

- Restoring is not the same as resetting to the catalogue default: a spec may run inside another
  spec's fixture. Capture the value seen at `before_each` and put *that* back.
- `CTLDConfig.get().settings` is the live table the engine reads. Restoring a `nil` means deleting the
  key, not writing `nil` into a list that `ipairs` walks.

## Acceptance

- Forward and reverse runs of `tests/ci/unit/` agree, and the count is unchanged.
- No spec depends on another having emptied `loadableGroups`.
- Whether `aircraft_capabilities_spec` keeps its defensive reset is decided in writing.

## Tests

The suite is the test. State in the PR which order(s) were run and the counts.


## What was actually found

1. **`troop_manager_spec` left `capabilitiesByType` absent** — the 29 failures, all in specs that read
   it (`_detectCapabilities`, the F10 menu gating). Fixed with `ctldTestSettings.borrow`.
2. **`jtac_drone_globals_spec` restored the setting but not the singleton.** It called
   `_processSpawnableCrates()` with fake crates: the manager kept a catalogue built from them, so
   every later spec asking for a descriptor got nothing. Restoring a setting is not enough once
   something has consumed it.
3. **A bug in the local runner itself**: it ran `after_each` in registration order, outermost first.
   Busted runs them innermost first, and nested borrow/restore only nests correctly that way round —
   the inner restore was landing last and re-applying the inner fixture's value. Fixed in
   `tools/lua-test/run_specs.lua`; the reverse run is what exposed it.
4. `type_collector_spec` wrote `modTypes = nil` to clean up, deleting a key the catalogue ships as
   `[]`. Harmless today, same class, now borrowed.

## The decision the ticket asked for

**FullGas's defensive `before_each` in `aircraft_capabilities_spec` stays.** Not as a patch over the
leak — that is fixed at the source — but because the spec genuinely needs a `CTLDTroopManager` built
from the real catalogue, and saying so in the spec is how the next reader knows the test depends on
it. A spec that states its own preconditions does not care what ran before it.
