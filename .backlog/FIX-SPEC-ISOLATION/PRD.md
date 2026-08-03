# FIX-SPEC-ISOLATION — two specs leave shared settings dirty, and the order is not deterministic

**Status:** open.

Opened 2026-08-03, from FullGas's fix in PR #91.

## What happened

`aircraft_capabilities_spec` read `CTLDTroopManager._templates` and asserted that a one-soldier
aircraft is offered exactly one troop template. **It passed locally and failed in CI.** FullGas fixed
the consumer side — a `before_each` resetting the singleton — which unblocked the build. The producer
is still there.

`troop_manager_spec` does this, and never puts it back:

```lua
before_each(function()
    CTLDTroopManager._instance = nil
    CTLDConfig.get().settings["loadableGroups"] = {}
    CTLDConfig.get().settings["capabilitiesByType"] = nil
end)
```

Every spec running after it sees an empty `loadableGroups` and no `capabilitiesByType`. Counted:
**`troop_manager_spec` mutates shared settings 9 times with zero `after_each`, `type_collector_spec`
8 times with zero** — `menu_gating_spec` is the only one of the three that restores.

## Why it is worth a lot rather than a reset in each reader

Because "which spec runs first" is not knowable. Busted walks `tests/ci/` and takes the order the
filesystem gives, which on Linux is a directory hash — arbitrary, and not stable between runs. The
local runner (`tools/lua-test/`) sorts by name, which is deterministic and therefore **blind to this
class of bug**: that is exactly why the failure appeared only in CI, and it is now written in that
runner's README.

Defending in every reader means every future spec that touches a template list, a capability table or
a singleton has to know which of its predecessors sabotaged it. Restoring in the two producers ends
it for everyone.

## Definition of done

- A spec that mutates `CTLDConfig.get().settings[...]` restores it, whatever the outcome of the test.
- Running the unit suite in **reverse** filename order gives the same result as forward — that is the
  cheap proof, and the local runner can do it since it takes the file list as arguments.
- FullGas's defensive `before_each` in `aircraft_capabilities_spec` can then go, or stay as a belt —
  say which and why.

## Out of scope

- Making busted's order deterministic. Tempting (`--sort`), but it would hide the next leak instead
  of fixing it; the suite should not care about order.
- The 194 dead FullGas relics, long since purged (`CLEANUP-LEGACY-DCS-TESTS`).
