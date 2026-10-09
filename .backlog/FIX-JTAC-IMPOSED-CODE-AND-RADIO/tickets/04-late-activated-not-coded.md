# 04 — A late-activated JTAC group is not coded at start

**Status:** ✅ done

Files: `src/CTLD_core.lua` (`_initMMJTACs`), `tests/ci/unit/core_manager_spec.lua`.

## What to do

- INIT-C reads activation on the group's first unit (`Unit.isActive`); DCS `Group` has no `isActive()`, and the failed call fell back to "active".

## Done when

- busted: a late-activated `*jtac*` group is marked pending and not registered at start; an active one is registered.
