# FIX-SPEC-ISOLATION

**Status:** merged (PR #94). Compacted from `FIX-SPEC-ISOLATION/` on 2026-10-09; the ticket files live on in git history.

`aircraft_capabilities_spec` passed locally and failed in CI: `troop_manager_spec` empties `loadableGroups` and nulls `CTLDTroopManager._instance` in a `before_each` and **never restores them**, so every spec running after it sees an emptied catalogue. FullGas fixed the consumer side in PR #91; the producer is still there — **9 mutations with zero `after_each` in `troop_manager_spec`, 8 in `type_collector_spec`**, `menu_gating_spec` being the only one of the three that restores. Worth fixing at the producer because "which spec runs first" is unknowable: busted takes the order the filesystem gives (a directory hash on Linux), while the local runner sorts by name and is therefore **blind to this class of bug** — which is why it only failed in CI. Cheap proof: a reversed-order run must agree with a forward one.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-restore-what-you-mutate` | done — reverse-order run went from **29 failures to 0**, and the starting point turned out | 01 — a spec that mutates a shared setting restores it |

## PRD

## FIX-SPEC-ISOLATION — two specs leave shared settings dirty, and the order is not deterministic

**Status:** open.

Opened 2026-08-03, from FullGas's fix in PR #91.

### What happened

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

### Why it is worth a lot rather than a reset in each reader

Because "which spec runs first" is not knowable. Busted walks `tests/ci/` and takes the order the
filesystem gives, which on Linux is a directory hash — arbitrary, and not stable between runs. The
local runner (`tools/lua-test/`) sorts by name, which is deterministic and therefore **blind to this
class of bug**: that is exactly why the failure appeared only in CI, and it is now written in that
runner's README.

Defending in every reader means every future spec that touches a template list, a capability table or
a singleton has to know which of its predecessors sabotaged it. Restoring in the two producers ends
it for everyone.

### Definition of done

- A spec that mutates `CTLDConfig.get().settings[...]` restores it, whatever the outcome of the test.
- Running the unit suite in **reverse** filename order gives the same result as forward — that is the
  cheap proof, and the local runner can do it since it takes the file list as arguments.
- FullGas's defensive `before_each` in `aircraft_capabilities_spec` can then go, or stay as a belt —
  say which and why.

### Out of scope

- Making busted's order deterministic. Tempting (`--sort`), but it would hide the next leak instead
  of fixing it; the suite should not care about order.
- The 194 dead FullGas relics, long since purged (`CLEANUP-LEGACY-DCS-TESTS`).
