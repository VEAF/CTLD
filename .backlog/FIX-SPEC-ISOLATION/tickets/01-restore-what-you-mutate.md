# 01 — a spec that mutates a shared setting restores it

**Status:** todo

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
